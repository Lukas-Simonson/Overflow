//
//  BufferPolicy.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/13/25.
//

public typealias MessageBufferPolicy<Element> = BufferPolicy<_Message<Element>>

public struct BufferPolicy<Element>: Sendable {
    private let factory: @Sendable () -> Buffer<Element>
    
    init(factory: @Sendable @escaping () -> Buffer<Element>) {
        self.factory = factory
    }
    
    func create() -> Buffer<Element> {
        return factory()
    }
}
