//
//  StateFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

public final class StateFlow<Element: Sendable>: Flow {
    fileprivate let state: State
    
    public var value: Element { get async { await state.value } }
    
    public init(initial element: Element) {
        self.state = State(initial: element)
    }
    
    fileprivate init(state: State) {
        self.state = state
    }
    
    public func makeAsyncIterator() -> Subscription {
        Subscription(state: state)
    }
}

public final class MutableStateFlow<Element: Sendable>: MutableFlow {
    typealias State = StateFlow<Element>.State
    public typealias Subscription = StateFlow<Element>.Subscription
    
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
    
    public func makeAsyncIterator() -> Subscription {
        Subscription(state: state)
    }
}

extension StateFlow {
    actor State: SharedBufferedEmitter {
        
        var value: Element
        
        var maxBufferSize: Int = 5
        var overflowContinuations = [UUID : [CheckedContinuation<Void, Never>]]()
        
        var waitingSubscriptions = [UUID : CheckedContinuation<Element, any Error>]()
        var buffers = [UUID : WeakBuffer<Subscription, Element>]()
        
        init(initial: Element) {
            self.value = initial
        }
        
        func register(_ subscription: Subscription) {
            if buffers[subscription.id] == nil {
                buffers[subscription.id] = WeakBuffer(key: subscription, buffer: [value])
            }
        }
        
        func emit(_ newValue: Element) async {
            value = newValue
            await _emit(newValue)
        }
    }
    
    public final class Subscription: SharedBufferedSubscription {
        public let id = UUID()
        let emitter: State
        
        init(state: State) {
            self.emitter = state
        }
        
        public func next() async -> Element? {
            await emitter.register(self)
            return try? await emitter.awaitNextValue(id: id)
        }
        
        public func register() async {
            await emitter.register(self)
        }
        
        public func cancel() async {
            await emitter.cancel(id: id)
        }
    }
}
