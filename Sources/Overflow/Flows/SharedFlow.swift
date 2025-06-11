//
//  SharedFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

/// A hot asynchronous flow that multicasts emitted values to all active subscribers.
///
/// Each subscriber receives values as they are emitted, sharing the same underlying buffer.
/// The flow is "hot", meaning values are produced regardless of the presence of subscribers.
///
/// - Parameter Element: The type of values emitted by the flow.
public final class SharedFlow<Element: Sendable>: Flow {
    
    /// The internal output emitter responsible for managing subscriptions and buffering.
    private let output: Output
    
    /// Initializes a new shared flow.
    public init() {
        self.output = Output()
    }
    
    /// Internal initializer used to convert MutableSharedFlow to SharedFlow
    fileprivate init(output: Output) {
        self.output = output
    }
    
    /// Creates an async iterator (subscription) for this flow.
    ///
    /// Each subscription receives values as they are emitted.
    ///
    /// - Returns: A `Subscription` for iterating over emitted values.
    public func makeAsyncIterator() -> Subscription {
        Subscription(output: output)
    }
}

/// A mutable hot asynchronous flow that allows emitting values to all active subscribers.
///
/// Values are multicast to all subscribers as they are emitted, sharing the same underlying buffer.
/// Use `emit(_:)` to send values, and `asSharedFlow()` to expose a read-only flow.
///
/// - Parameter Element: The type of values emitted by the flow.
public final class MutableSharedFlow<Element: Sendable>: MutableFlow {
    
    typealias Output = SharedFlow<Element>.Output
    public typealias Subscription = SharedFlow<Element>.Subscription
    
    /// The internal output emitter responsible for managing subscriptions and buffering.
    private let output: Output
    
    /// Initializes a new mutable shared flow.
    public init() {
        output = Output()
    }
    
    /// Emits a value to all active subscribers.
    /// - Parameter value: The value to emit.
    public func emit(_ value: Element) async {
        await self.output.emit(value)
    }
    
    /// Returns a read-only `SharedFlow` view of this mutable flow.
    /// - Returns: A `SharedFlow` instance sharing the same buffer and subscriptions.
    public func asSharedFlow() -> SharedFlow<Element> {
        SharedFlow(output: output)
    }
    
    /// Creates an async iterator (subscription) for this flow.
    ///
    /// Each subscription receives values as they are emitted.
    ///
    /// - Returns: A `Subscription` for iterating over emitted values.
    public func makeAsyncIterator() -> Subscription {
        Subscription(output: output)
    }
}

extension SharedFlow {
    
    /// The actor responsible for buffering and emitting values to subscribers.
    actor Output: SharedBufferedEmitter {
        
        /// The maximum number of buffered elements per subscriber.
        var maxBufferSize: Int = 5
        
        /// Continuations for handling buffer overflows.
        var overflowContinuations = [UUID : [CheckedContinuation<Void, Never>]]()
        
        /// Continuations for awaiting the next value per subscription.
        var waitingSubscriptions = [UUID : CheckedContinuation<Element, any Error>]()
        
        /// Buffers holding emitted elements for each subscription.
        var buffers = [UUID : WeakBuffer<Subscription, Element>]()
    }
    
    /// The subscription type for iterating over values emitted by a SharedFlow.
    public final class Subscription: SharedBufferedSubscription {
        
        public let id = UUID()
        let emitter: Output
        
        init(output: Output) {
            self.emitter = output
        }
        
        /// Returns the next value from the flow, or nil if the flow is closed.
        public func next() async -> Element? {
            await register()
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
