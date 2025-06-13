//
//  SignalEmitter.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

public final class MutableSignalFlow<Element: Sendable>: MutableFlow {
    
    private let publisher: Publisher
    
    public init() {
        publisher = Publisher()
    }
    
    public func emit(_ value: Element) async {
        await publisher.emit(value)
    }
    
    public func makeAsyncIterator() -> Subscriber {
        Subscriber(publisher: publisher)
    }
}

extension MutableSignalFlow {
    public actor Subscriber: BufferedSubscriber {
        public let id = UUID()
        
        weak var publisher: Publisher?
        var buffer = [Message<Element>]()
        var continuation: CheckedContinuation<Element, Never>?
        
        init(publisher: Publisher) {
            self.publisher = publisher
        }
        
        public func register() async { await _register() }
        public func send(_ value: Element) async { await _send(value) }
        public func close() async { await _close() }
        public func next() async -> Element? { await _next() }
    }
    
    actor Publisher: SharedPublisher {
        typealias Sub = MutableSignalFlow<Element>.Subscriber
        
        var subscribers = [UUID : Weak<Sub>]()
    }
}
