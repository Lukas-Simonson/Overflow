//
//  BufferedSubscriber.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

internal enum Message<Element: Sendable> {
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
    var buffer: [Message<Element>] { get set }
    var continuation: CheckedContinuation<Element, Never>? { get set }
}

extension BufferedSubscriber {
    public func _register() async {
        guard let publisher else { return }
        await publisher.register(self)
    }
    
    public func _send(_ value: Element) async {
        if let continuation {
            continuation.resume(returning: value)
            self.continuation = nil
        } else {
            buffer.append(.element(value))
        }
    }
    
    public func _next() async -> Element? {
        await _register()
        if !buffer.isEmpty {
            return buffer.removeFirst().value
        }
        
        return await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }
    
    public func _close() async {
        buffer.append(.close)
    }
}
