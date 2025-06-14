//
//  StallBufferTests.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/13/25.
//

import Testing
@testable import Overflow

@Suite("StallBuffer Tests")
struct StallBufferTests {
    
    @Test("Buffers values up to maxSize and returns them in order")
    func testBuffering() async {
        let buffer = StallBuffer<Int>(maxSize: 2)
        await buffer.add(1)
        await buffer.add(2)
        let first = await buffer.next()
        let second = await buffer.next()
        let third = await buffer.next()
        #expect(first == 1)
        #expect(second == 2)
        #expect(third == nil)
    }
    
    @Test("Stalls add when buffer is full and resumes after next is called")
    func testStallingAndResuming() async {
        let buffer = StallBuffer<Int>(maxSize: 1)
        await buffer.add(10)
        var didAdd = false
        
        Task {
            await buffer.add(20)
            didAdd = true
        }
        
        // Give the addTask a moment to attempt to add and stall
        try? await Task.sleep(for: .milliseconds(5))
        #expect(didAdd == false)
        
        // Remove one item to make space and allow stalled add to proceed
        let _ = await buffer.next()
        
        // Give the addTask a moment to resume
        try? await Task.sleep(for: .milliseconds(5))
        #expect(didAdd == true)
        
        let nextValue = await buffer.next()
        #expect(nextValue == 20)
        
        print("Passed Stalling")
    }
    
    @Test("Stress test: values stay in order and no deadlocks")
    func testStressOrderAndNoDeadlock() async {
        let buffer = StallBuffer<Int>(maxSize: 10)
        let total = 100
        var results = [Int]()
        
        async let producer: Void = {
            for i in 0..<total {
                await buffer.add(i)
            }
        }()
        
        async let consumer: Void = {
            for _ in 0..<total {
                try? await Task.sleep(for: .milliseconds(1))
                if let value = await buffer.next() {
                    results.append(value)
                }
            }
        }()
        
        _ = await (producer, consumer)
        
        #expect(results.count == total)
        #expect(results == Array(0..<total))
    }
}
