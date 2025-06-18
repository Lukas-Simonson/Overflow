//
//  StallBuffer.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/13/25.
//

public extension BufferPolicy {
    static func stalling(maxSize: Int) -> BufferPolicy<Element> {
        BufferPolicy { StallBuffer(maxSize: maxSize) }
    }
}

public class StallBuffer<Element>: Buffer<Element>, @unchecked Sendable {
    private let maxSize: Int
    private var stalls = [CheckedContinuation<Void, Never>]()
    
    init(maxSize: Int) {
        assert(maxSize >= 1, "Buffer size must be at least 1")
        self.maxSize = maxSize
    }
    
    public override func add(_ value: Element) async {
        await withCheckedContinuation { cont in
            lock.withLock {
                if count >= maxSize {
                    stalls.append(cont)
                } else {
                    cont.resume()
                }
            }
        }
        await super.add(value)
    }
    
    public override func next() async -> Element? {
        lock.withLock {
            if !stalls.isEmpty {
                stalls.removeFirst().resume()
            }
        }
        return await super.next()
    }
}
