//
//  StateFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

fileprivate protocol StateFlowProtocol: Sendable, Flow where AsyncIterator == Subscription {
    typealias State = StateFlow<Element>.State
    typealias Subscription = StateFlow<Element>.Subscription
    
    var state: State { get }
    var value: Element { get async }
    
    init(initial: Element)
}

extension StateFlowProtocol {    
    public func makeAsyncIterator() -> Subscription {
        Subscription(state: state)
    }
}

public final class StateFlow<Element: Sendable>: StateFlowProtocol {
    fileprivate let state: State
    
    public var value: Element { get async { await state.value } }
    
    public init(initial element: Element) {
        self.state = State(initial: element)
    }
    
    fileprivate init(state: State) {
        self.state = state
    }
}

public final class MutableStateFlow<Element: Sendable>: MutableFlow, StateFlowProtocol {
    fileprivate let state: State
    
    public var value: Element { get async { await state.value } }
    
    public init(initial element: Element) {
        self.state = State(initial: element)
    }
    
    public func emit(_ value: Element) async {
        await self.state.emit(value)
    }
    
    public func asStateFlow() -> StateFlow<Element> {
        StateFlow(state: state)
    }
}

// MARK: State
extension StateFlow {
    actor State {
        
        private let maxBufferSize = 5
        private var overflowContinuations = [UUID: [CheckedContinuation<Void, Never>]]()
        
        /// The current value.
        private(set) var value: Element
        
        /// The list of continuations waiting for the next value.
        private var continuations = [UUID: CheckedContinuation<Element, any Error>]()
        
        /// The buffers of all subscribers.
        private var buffers = [UUID: WeakBuffer<Subscription, Element>]()
        
        /// Initializes with an initial value.
        /// - Parameter initial: The initial value.
        init(initial: Element) {
            self.value = initial
        }
        
        func register(_ subscription: Subscription) {
            if buffers[subscription.id] == nil {
                // Create new buffer, with current value.
                buffers[subscription.id] = WeakBuffer(key: subscription, buffer: [value])
            }
        }
        
        func cancel(id: UUID) {
            buffers.removeValue(forKey: id)
            let cont = continuations.removeValue(forKey: id)
            cont?.resume(throwing: ContinuationError.continuationOwnerExitedScope)
        }
        
        /// Emits a new value and resumes all waiting subscribers.
        /// - Parameter newValue: the value to emit
        func emit(_ newValue: Element) async {
            value = newValue
            
            for id in buffers.keys {
                guard var buffer = buffers[id] else { continue }
                
                // Remove buffer is Subscription has left scope.
                if buffer.isCleared {
                    cancel(id: id)
                }
                
                // Handle any current continuations before adding to buffer.
                else if let cont = continuations.removeValue(forKey: id) {
                    // No values should be in buffer; however, if there are, emit the first buffered value, then update the buffer.
                    if let buffed = buffer.removeFirst() {
                        cont.resume(returning: buffed)
                        buffer.append(newValue)
                        buffers[id] = buffer // Update buffers with updated buffer.
                    } else {
                        // Continue the waiting subscription without adding to buffer.
                        cont.resume(returning: newValue)
                    }
                }
                
                // If the buffer is needed, add value to the buffer.
                else {
                    buffer.append(value)
                    buffers[id] = buffer // Update buffers with updated buffer.
                    
                    // Handle buffer overflow
                    if buffer.size > maxBufferSize {
                        await withCheckedContinuation { cont in
                            overflowContinuations[id, default: []].append(cont)
                        }
                    }
                }
            }
        }
        
        /// Suspends until the next value is emitted, then returns it.
        /// - Returns the next emitted value.
        func awaitNextValue(id: UUID) async throws -> Element {
            if var buffer = buffers[id], let first = buffer.removeFirst() {
                buffers[id] = buffer // Update buffer with removed value
                
                if var conts = overflowContinuations[id], !conts.isEmpty {
                    conts.removeFirst().resume()
                    overflowContinuations[id] = conts.isEmpty ? nil : conts
                }
                
                return first
            }
            
            guard continuations[id] == nil else { fatalError("Continuation not called before being removed") }
            
            // No Buffer, await next value
            return try await withCheckedThrowingContinuation { cont in
                 continuations[id] = cont
            }
        }
    }
}

// MARK: Subscription
extension StateFlow {
    public final class Subscription: Sendable, AsyncIteratorProtocol {
        
        /// The Unique ID of this Subscription
        let id = UUID()
        
        /// The state actor to observe.
        private let state: State
        
        /// Initializes the subscription with a state actor.
        /// - Parameter state: The state to observe.
        init(state: State) {
            self.state = state
        }
        
        /// Returns the next value in the sequence, suspending until a new value is available.
        public func next() async -> Element? {
            await state.register(self)
            return try? await state.awaitNextValue(id: id)
        }
        
        public func cancel() async {
            await state.cancel(id: id)
        }
    }
}

