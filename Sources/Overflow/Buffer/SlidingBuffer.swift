//
//  SlidingBuffer.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/13/25.
//

public extension BufferPolicy {
    static func sliding(maxSize: Int) -> BufferPolicy<Element> {
        BufferPolicy { SlidingBuffer(maxSize: maxSize) }
    }
}

public class SlidingBuffer<Element>: Buffer<Element>, @unchecked Sendable {
    private let maxSize: Int
    
    init(maxSize: Int) {
        assert(maxSize >= 1, "Buffer size must be at least 1")
        self.maxSize = maxSize
    }
    
    public override func add(_ value: Element) async {
        lock.withLock {
            if count >= maxSize {
                values.removeFirst()
            }
            
            values.append(value)
        }
    }
}
