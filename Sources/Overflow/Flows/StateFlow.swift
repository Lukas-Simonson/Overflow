//
//  StateFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

/// A stateful hot asynchronous flow that always holds and emits the latest value to subscribers.
///
/// Each subscriber receives the current value immediately upon subscription, followed by any new values as they are emitted.
///
/// The flow is "hot", meaning it maintains state and emits values regardless of the presence of subscribers.
///
/// - Parameter Element: The type of values held and emitted by the flow.
public final class StateFlow<Element: Sendable>: Flow {
    
    /// The internal actor managing state and subscriptions.
    private let state: State
    
    /// The current value of the flow. Always returns the latest value.
    public var value: Element { get async { await state.value } }
    
    /// Internal initializer used to convert MutableStateFlow to StateFlow.
    fileprivate init(state: State) {
        self.state = state
    }
    
    /// Creates an async iterator (subscription) for this flow.
    /// Each subscription receives the current value and subsequent updates.
    /// - Returns: A `Subscription` for iterating over emitted values.
    public func makeAsyncIterator() -> Subscription {
        Subscription(state: state)
    }
}

/// A mutable stateful hot asynchronous flow that always holds and emits the latest value to subscribers.
/// Allows updating the current value using `emit(_:)`, and exposes a read-only view via `asStateFlow()`.
/// Each subscriber receives the current value immediately upon subscription, followed by any new values as they are emitted.
///
/// - Parameter Element: The type of values held and emitted by the flow.
public final class MutableStateFlow<Element: Sendable>: MutableFlow {
    
    typealias State = StateFlow<Element>.State
    public typealias Subscription = StateFlow<Element>.Subscription
    
    /// The internal actor managing state and subscriptions.
    private let state: State
    
    /// The current value of the flow. Always returns the latest value.
    public var value: Element { get async { await state.value } }
    
    /// Initializes a new mutable state flow with the provided initial value.
    /// - Parameter element: The initial value of the flow.
    public init(initial element: Element) {
        self.state = State(initial: element)
    }
    
    /// Emits a new value to all active subscribers and updates the current value.
    /// - Parameter value: The value to emit.
    public func emit(_ value: Element) async {
        await self.state.emit(value)
    }
    
    /// Returns a read-only `StateFlow` view of this mutable flow.
    /// - Returns: A `StateFlow` instance sharing the same state and subscriptions.
    public func asStateFlow() -> StateFlow<Element> {
        StateFlow(state: state)
    }
    
    /// Creates an async iterator (subscription) for this flow.
    /// Each subscription receives the current value and subsequent updates.
    /// - Returns: A `Subscription` for iterating over emitted values.
    public func makeAsyncIterator() -> Subscription {
        Subscription(state: state)
    }
}

extension StateFlow {
    
    /// The actor responsible for holding the current value and managing subscriptions.
    actor State: SharedBufferedEmitter {
        
        /// The current value held by the flow.
        var value: Element
        
        /// The maximum number of buffered elements per subscriber.
        var maxBufferSize: Int = 5
        
        /// Continuations for handling buffer overflows.
        var overflowContinuations = [UUID : [CheckedContinuation<Void, Never>]]()
        
        /// Continuations for awaiting the next value per subscription.
        var waitingSubscriptions = [UUID : CheckedContinuation<Element, any Error>]()
        
        /// Buffers holding emitted elements for each subscription.
        var buffers = [UUID : WeakBuffer<Subscription, Element>]()
        
        /// Initializes the state with an initial value.
        /// - Parameter initial: The initial value.
        init(initial: Element) {
            self.value = initial
        }
        
        /// Registers a subscription, ensuring it receives the current value.
        /// - Parameter subscription: The subscription to register.
        func register(_ subscription: Subscription) {
            if buffers[subscription.id] == nil {
                buffers[subscription.id] = WeakBuffer(key: subscription, buffer: [value])
            }
        }
        
        /// Emits a new value to all active subscribers.
        /// - Parameter newValue: The value to emit.
        func emit(_ newValue: Element) async {
            value = newValue
            await _emit(newValue)
        }
    }
    
    /// The subscription type for iterating over values emitted by the flow.
    public final class Subscription: SharedBufferedSubscription {
        
        /// The unique identifier for the subscription.
        public let id = UUID()
        
        /// The emitter managing state and value delivery.
        let emitter: State
        
        /// Initializes a new subscription for the given state.
        /// - Parameter state: The state actor to subscribe to.
        fileprivate init(state: State) {
            self.emitter = state
        }
        
        /// Returns the next value from the flow, or nil if the flow is closed.
        public func next() async -> Element? {
            await emitter.register(self)
            return try? await emitter.awaitNextValue(id: id)
        }
        
        /// Registers the subscription with the emitter.
        ///
        /// This allows a buffer to fill with values, prior to collecting them.
        /// Registration is handled manually by default when you start collecting values.
        ///
        /// - WARNING: Registering a Subscription and not collecting from it can lead to the flow freezing. Only use sparingly.
        public func register() async {
            await emitter.register(self)
        }
        
        /// Cancels the subscription, removing it from the emitter.
        ///
        /// This happens automatically when the reference to the Subscription exists scope.
        /// You can call cancel manually to clear its buffer immediately.
        public func cancel() async {
            await emitter.cancel(id: id)
        }
    }
}

func test() {
    let flow = MutableStateFlow(initial: 0)
    flow.emit(1)
}
