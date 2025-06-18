//
//  SharedFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

public final class SharedFlow<Element: Sendable>: Flow {
    public typealias Subscriber = MutableSharedFlow<Element>.Subscriber
    typealias Publisher = MutableSharedFlow<Element>.Publisher
    
    private let publisher: Publisher
    private let bufferPolicy: MessageBufferPolicy<Element>
    
    fileprivate init(publisher: Publisher, bufferPolicy: MessageBufferPolicy<Element>) {
        self.publisher = publisher
        self.bufferPolicy = bufferPolicy
    }
    
    public func makeAsyncIterator() -> Subscriber {
        Subscriber(publisher: publisher, buffer: bufferPolicy.create())
    }
}

public final class MutableSharedFlow<Element: Sendable>: MutableFlow {
    
    private let publisher: Publisher
    private let bufferPolicy: MessageBufferPolicy<Element>
    
    public init(
        bufferPolicy: MessageBufferPolicy<Element> = .stalling(maxSize: 5)
    ) {
        self.publisher = Publisher()
        self.bufferPolicy = bufferPolicy
    }
    
    public func emit(_ value: Element) async {
        await publisher.emit(value)
    }
    
    public func asSharedFlow() -> SharedFlow<Element> {
        let sharedFlow = SharedFlow(publisher: publisher, bufferPolicy: bufferPolicy)
        return sharedFlow
    }
    
    public func makeAsyncIterator() -> Subscriber {
        Subscriber(publisher: publisher, buffer: bufferPolicy.create())
    }
}

extension MutableSharedFlow {
    public actor Subscriber: BufferedSubscriber {
        public let id = UUID()
        
        weak var publisher: Publisher?
        var buffer: MessageBuffer<Element>
        var continuation: CheckedContinuation<Element?, Never>?
        
        init(publisher: Publisher, buffer: MessageBuffer<Element>) {
            self.publisher = publisher
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
            if let result = await _next() {
                return result
            }
            return nil
        }
    }
    
    actor Publisher: SharedPublisher {
        typealias Sub = MutableSharedFlow<Element>.Subscriber
        
        var subscribers = [UUID : Weak<Sub>]()
        
        var isEmitting = false
        var emissionQueue = [Element]()
    }
}
