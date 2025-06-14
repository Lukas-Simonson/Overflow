//
//  Buffer.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

public extension BufferPolicy {
    static func unbounded() -> BufferPolicy<Element> {
        BufferPolicy { Buffer() }
    }
}

open class Buffer<Element>: @unchecked Sendable {
    
    open var isEmpty: Bool { values.isEmpty }
    
    var count: Int { values.count }
    var values = [Element]()
    
    var lock = NSLock()
    
    open func add(_ value: Element) async {
        lock.withLock {
            values.append(value)
        }
    }
    
    open func next() async -> Element? {
        return lock.withLock {
            guard !values.isEmpty else { return nil }
            return values.removeFirst()
        }
    }
}
