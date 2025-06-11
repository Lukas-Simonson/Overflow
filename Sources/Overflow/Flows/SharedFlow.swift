//
//  SharedFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

public final class SharedFlow<Element: Sendable>: Flow {
    fileprivate let output: Output
    
    public init() {
        self.output = Output()
    }
    
    fileprivate init(output: Output) {
        self.output = output
    }
    
    public func makeAsyncIterator() -> Subscription {
        Subscription(output: output)
    }
}

public final class MutableSharedFlow<Element: Sendable>: MutableFlow {
    typealias Output = SharedFlow<Element>.Output
    public typealias Subscription = SharedFlow<Element>.Subscription
    
    fileprivate let output: Output
    
    public init() {
        output = Output()
    }
    
    public func emit(_ value: Element) async {
        await self.output.emit(value)
    }
    
    public func asSharedFlow() -> SharedFlow<Element> {
        SharedFlow(output: output)
    }
    
    public func makeAsyncIterator() -> Subscription {
        Subscription(output: output)
    }
}

extension SharedFlow {
    actor Output: SharedBufferedEmitter {
        var maxBufferSize: Int = 5
        var overflowContinuations = [UUID : [CheckedContinuation<Void, Never>]]()
        
        var waitingSubscriptions = [UUID : CheckedContinuation<Element, any Error>]()
        var buffers = [UUID : WeakBuffer<Subscription, Element>]()
    }
    
    public final class Subscription: SharedBufferedSubscription {
        
        public let id = UUID()
        let emitter: Output
        
        init(output: Output) {
            self.emitter = output
        }
        
        public func next() async -> Element? {
            await register()
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
