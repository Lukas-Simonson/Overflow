//
//  ColdFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

public typealias EmitAction<E: Sendable> = @Sendable (E) async -> Void

public func flow<E: Sendable>(
    _ builder: @Sendable @escaping (EmitAction<E>) async -> Void
) -> some Flow {
    ColdFlow(builder: builder)
}

public final class ColdFlow<Element: Sendable>: Flow {
    
    let builder: @Sendable (EmitAction<Element>) async -> Void
    
    public init(builder: @Sendable @escaping (EmitAction<Element>) async -> Void) {
        self.builder = builder
    }
    
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
    public actor Emitter: BufferedEmitter {
        
        public var continuation: CheckedContinuation<Element?, any Error>? = nil

        public var maxBufferSize: Int = 5
        public var buffer: [Element] = []
    }
    
    public final class Subscription: BufferedSubscription {
        let emitter: Emitter
        
        init(emitter: Emitter) {
            self.emitter = emitter
        }
        
        public func next() async -> Element? {
            try? await emitter.awaitNextValue()
        }
    }
}
