//
//  ColdFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

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
    return ColdFlow(builder: builder)
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
    
    private let bufferPolicy: MessageBufferPolicy<Element>
    
    /// Initializes a new cold flow with the provided builder.
    /// - Parameter builder: An async closure that emits values using the provided `EmitAction`.
    public init(
        bufferPolicy: MessageBufferPolicy<Element> = .stalling(maxSize: 5),
        builder: @Sendable @escaping (EmitAction<Element>) async -> Void
    ) {
        self.bufferPolicy = bufferPolicy
        self.builder = builder
    }
    
    /// Creates an async iterator (subscription) for this flow.
    /// Each call starts a new execution of the builder.
    /// - Returns: A `Subscription` for iterating over emitted values.
    public func makeAsyncIterator() -> Subscriber {
        let sub = Subscriber(buffer: bufferPolicy.create())
        let publisher = Pub(sub: sub)
        Task {
            await builder { value in
                await publisher.emit(value)
            }
            await publisher.close()
        }
        return sub
    }
}

extension ColdFlow {
    
    public actor Subscriber: BufferedSubscriber {
        public let id = UUID()
        
        weak var publisher: Pub?
        var buffer: MessageBuffer<Element>
        var continuation: CheckedContinuation<Element?, Never>?
        
        init(buffer: MessageBuffer<Element>) {
            self.publisher = nil
            self.buffer = buffer
        }
        
        public func register() async {
            await _register()
        }
        public func send(_ value: Element) async {
            await _send(value)
        }
        public func close() async {
            await _close()
        }
        public func next() async -> Element? {
            return await _next()
        }
    }
    actor Pub: Publisher {
        typealias Sub = ColdFlow<Element>.Subscriber
        
        private weak var sub: Sub!
        
        init(sub: Sub) {
            self.sub = sub
        }
        
        func emit(_ newValue: Element) async {
            await sub!.send(newValue)
        }
        
        func close() async {
            await sub!.close()
        }
        
        func register(_ subscriber: Sub) async {
            guard sub == nil else { return }
            sub = subscriber
        }
    }
}
