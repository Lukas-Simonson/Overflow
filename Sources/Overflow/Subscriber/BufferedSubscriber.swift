//
//  BufferedSubscriber.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

public enum _Message<Element: Sendable>: Sendable {
    case element(Element)
    case close
    
    var value: Element? {
        switch self {
            case .element(let e): e
            case .close: nil
        }
    }
}

internal protocol BufferedSubscriber: Actor, Subscriber {
    associatedtype Pub: Publisher where Pub.Sub == Self
    
    var publisher: Pub? { get set }
    var buffer: MessageBuffer<Element> { get }
    var continuation: CheckedContinuation<Element?, Never>? { get set }
    
    func register() async
}

extension BufferedSubscriber {
    public func _register() async {
        guard let publisher else {
            return
        }
        self.publisher = nil
        await publisher.register(self)
    }
    
    public func _send(_ value: Element) async {
        await buffer.add(.element(value))
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: await buffer.next()?.value)
        }
    }
    
    public func _next() async -> Element? {
        await register()
        if !buffer.isEmpty {
            return await buffer.next()?.value
        }
        return await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }
    
    public func _close() async {
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: nil)
        } else {
            await buffer.add(.close)
        }
    }
}
