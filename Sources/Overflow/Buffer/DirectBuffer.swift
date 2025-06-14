//
//  DirectBuffer.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/13/25.
//

public extension BufferPolicy {
    static func direct() -> BufferPolicy<Element> {
        BufferPolicy { DirectBuffer() }
    }
}

public class DirectBuffer<Element>: Buffer<Element>, @unchecked Sendable {
    
    public override var isEmpty: Bool { true }
    
    public override func add(_ value: Element) async {
        return
    }
    
    public override func next() async -> Element? {
        return nil
    }
}
