//
//  ColdFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

public final class ColdFlow<Element: Sendable>: Flow {
    let builder: @Sendable (isolated Emitter) async -> Void
    
    public init(builder: @Sendable @escaping (isolated Emitter) async -> Void) {
        self.builder = builder
    }
    
    public func makeAsyncIterator() -> Subscription {
        let emitter = Emitter()
        
        Task {
            await builder(emitter)
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
