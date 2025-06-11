//
//  Weak.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

/// A buffer that holds elements associated with a weakly referenced key object.
///
/// Used to manage per-subscriber buffers in emitter implementations, automatically
/// invalidating the buffer when the key object is deallocated.
///
/// - Parameters:
///   - Key: The type of the key object, which must be a class.
///   - Element: The type of elements stored in the buffer.
public struct WeakBuffer<Key: AnyObject, Element> {
    
    /// The weakly referenced key object. If this becomes nil, the buffer is considered cleared.
    private weak var key: Key?
    
    /// The array buffer holding the elements.
    private var buffer: [Element]
    
    /// Initializes a new buffer for the given key and initial elements.
    ///
    /// - Parameters:
    ///   - key: The key object to associate with this buffer.
    ///   - buffer: The initial elements to store in the buffer.
    init(key: Key, buffer: [Element]) {
        self.key = key
        self.buffer = buffer
    }
    
    /// Indicates whether the key object has been deallocated.
    var isCleared: Bool { key == nil }
    
    /// Indicates whether the buffer is empty.
    var isEmpty: Bool { buffer.isEmpty }
    
    /// The number of elements currently in the buffer.
    var size: Int { buffer.count }
    
    /// Appends an element to the buffer.
    ///
    /// - Parameter element: The element to append.
    mutating func append(_ element: Element) {
        self.buffer.append(element)
    }
    
    /// Removes and returns the first element from the buffer, or nil if empty.
    ///
    /// - Returns: The first element, or nil if the buffer is empty.
    mutating func removeFirst() -> Element? {
        guard !buffer.isEmpty else { return nil }
        return self.buffer.removeFirst()
    }
}

public struct Weak<T: AnyObject & Sendable>: Sendable {
    private weak var _value: T?
    var value: T? { _value }
    
    init(_ value: T) {
        self._value = value
    }
}
