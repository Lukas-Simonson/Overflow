//
//  Weak.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

struct WeakBuffer<Key: AnyObject, Element> {
    private weak var key: Key?
    private var buffer: [Element]
    
    init(key: Key, buffer: [Element]) {
        self.key = key
        self.buffer = buffer
    }
    
    var isCleared: Bool { key == nil }
    var isEmpty: Bool { buffer.isEmpty }
    var size: Int { buffer.count }
    
    mutating func append(_ element: Element) {
        self.buffer.append(element)
    }
    
    mutating func removeFirst() -> Element? {
        guard !buffer.isEmpty else { return nil }
        return self.buffer.removeFirst()
    }
}
