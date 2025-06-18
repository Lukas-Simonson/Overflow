//
//  StateFlow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation
import OSLog

public final class StateFlow<Element: Sendable>: Flow {
    typealias Publisher = MutableStateFlow<Element>.Publisher
    public typealias Subscriber = MutableStateFlow<Element>.Subscriber
    
    private let publisher: Publisher
    private let bufferPolicy: MessageBufferPolicy<Element>
    
    public var value: Element { get async { await publisher.value } }
    
    fileprivate init(publisher: Publisher, bufferPolicy: MessageBufferPolicy<Element>) {
        self.publisher = publisher
        self.bufferPolicy = bufferPolicy
    }
    
    public func makeAsyncIterator() -> Subscriber {
        Subscriber(publisher: publisher, buffer: bufferPolicy.create())
    }
}

public final class MutableStateFlow<Element: Sendable>: MutableFlow {
    
    private let publisher: Publisher
    private let bufferPolicy: MessageBufferPolicy<Element>
    
    public var value: Element { get async { await publisher.value } }
    
    public init(initial value: Element, bufferPolicy: MessageBufferPolicy<Element> = .stalling(maxSize: 5)) {
        self.publisher = Publisher(initialValue: value)
        self.bufferPolicy = bufferPolicy
    }
    
    public func emit(_ value: Element) async {
        await publisher.emit(value)
    }
    
    public func asStateFlow() -> StateFlow<Element> {
        StateFlow(publisher: publisher, bufferPolicy: bufferPolicy)
    }
    
    public func makeAsyncIterator() -> Subscriber {
        Subscriber(publisher: publisher, buffer: bufferPolicy.create())
    }
}

extension MutableStateFlow {
    public actor Subscriber: BufferedSubscriber {
        public let id = UUID()
        
        weak var publisher: Publisher?
        var buffer: MessageBuffer<Element>
        var continuation: CheckedContinuation<Element?, Never>?
        
        init(publisher: Publisher? = nil, buffer: MessageBuffer<Element>) {
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
            await _next()
        }
    }
    
    
    actor Publisher: SharedPublisher {
        var value: Element
        var subscribers = [UUID : Weak<Sub>]()
        
        var isEmitting = false
        var emissionQueue = [Element]()
        
        init(initialValue: Element) {
            self.value = initialValue
        }
        func emit(_ newValue: Element) async {
            value = newValue
            await _emit(newValue)
        }
        func register(_ subscriber: Subscriber) async {
            await subscriber.send(value)
            subscribers[subscriber.id] = Weak(subscriber)
        }
    }
}
