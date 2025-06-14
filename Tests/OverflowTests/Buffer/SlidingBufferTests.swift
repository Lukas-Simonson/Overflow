//
//  SlidingBufferTests.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/13/25.
//

import Testing
@testable import Overflow

@Suite("SlidingBuffer Tests")
struct SlidingBufferTests {
    @Test("Adding less than maxSize elements keeps all elements")
    func testBufferUnderCapacity() async {
        let buffer = SlidingBuffer<Int>(maxSize: 3)
        await buffer.add(1)
        await buffer.add(2)
        #expect(buffer.values == [1, 2])
    }
    
    @Test("Adding exactly maxSize elements keeps all elements")
    func testBufferAtCapacity() async {
        let buffer = SlidingBuffer<Int>(maxSize: 3)
        await buffer.add(1)
        await buffer.add(2)
        await buffer.add(3)
        #expect(buffer.values == [1, 2, 3])
    }
    
    @Test("Adding more than maxSize elements drops oldest")
    func testBufferOverCapacity() async {
        let buffer = SlidingBuffer<Int>(maxSize: 3)
        await buffer.add(1)
        await buffer.add(2)
        await buffer.add(3)
        await buffer.add(4)
        #expect(buffer.values == [2, 3, 4])
    }
}
