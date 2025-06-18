//
//  Buffer.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

public typealias MessageBuffer<Element> = Buffer<_Message<Element>>

public extension BufferPolicy {
    static func unbounded() -> BufferPolicy<Element> {
        BufferPolicy { Buffer() }
    }
}

open class Buffer<Element>: @unchecked Sendable {
    
    open var isEmpty: Bool {
        return lock.withLock {
            values.isEmpty
        }
    }
    
    var count: Int {
        return lock.withLock {
            values.count
        }
    }
    var values = [Element]()
    
    var lock = NSRecursiveLock()
    
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
