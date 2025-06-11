//
//  ColdFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

/// An async sendable closure used to emit values from a flow builder.
/// Call this closure with a value to emit it to all current subscribers.
///
/// - Parameter value: The value to emit to subscribers.
public typealias EmitAction<E: Sendable> = @Sendable (E) async -> Void

/// Creates a cold asynchronous flow using the provided builder closure.
///
/// The builder is executed anew for each subscriber, and uses the `EmitAction`
/// to emit values asynchronously to the flow's subscribers.
///
/// - Parameter builder: An async closure that emits values using the provided `EmitAction`.
/// - Returns: A new cold flow instance that emits values of type `E`.
public func flow<E: Sendable>(
    _ builder: @Sendable @escaping (EmitAction<E>) async -> Void
) -> some Flow {
    ColdFlow(builder: builder)
}

/// A cold asynchronous flow that emits values to subscribers when collected.
///
/// The flow is "cold", meaning the builder block is executed anew for each subscriber.
///
/// - Parameter Element: The type of values emitted by the flow.
public final class ColdFlow<Element: Sendable>: Flow {
    
    /// The builder closure that produces values for the flow.
    /// It receives an `EmitAction` to emit values asynchronously.
    private let builder: @Sendable (EmitAction<Element>) async -> Void
    
    /// Initializes a new cold flow with the provided builder.
    /// - Parameter builder: An async closure that emits values using the provided `EmitAction`.
    public init(builder: @Sendable @escaping (EmitAction<Element>) async -> Void) {
        self.builder = builder
    }
    
    /// Creates an async iterator (subscription) for this flow.
    /// Each call starts a new execution of the builder.
    /// - Returns: A `Subscription` for iterating over emitted values.
    public func makeAsyncIterator() -> Subscription {
        let emitter = Emitter()
        
        Task {
            await builder(emitter.emit(_:))
            await emitter.close()
        }
        
        return Subscription(emitter: emitter)
    }
}

extension ColdFlow {
    
    /// The actor responsible for buffering and emitting values to subscribers of a ColdFlow.
    public actor Emitter: BufferedEmitter {
        
        /// The continuation used for resuming an awaiting subscriber.
        public var continuation: CheckedContinuation<Element?, any Error>? = nil

        /// The maximum number of buffered elements.
        public var maxBufferSize: Int = 5
        
        /// The buffer holding emitted elements.
        public var buffer: [Element] = []
    }
    
    /// The subscription type for iterating over values emitted by the flow.
    public final class Subscription: BufferedSubscription {
        
        let emitter: Emitter
        
        fileprivate init(emitter: Emitter) {
            self.emitter = emitter
        }
        
        /// Returns the next value from the flow, or nil if the flow is closed.
        public func next() async -> Element? {
            try? await emitter.awaitNextValue()
        }
    }
}
