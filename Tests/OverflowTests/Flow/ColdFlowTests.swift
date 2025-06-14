//
//  ColdFlowTests.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Testing
import Overflow

@Suite("Cold Flow Tests")
struct ColdFlowTests {
    
    @Test("Cold Flow Emits Multiple Values")
    func testMultipleValues() async {
        let testValues = ["Hello", "World", "!"]
        let flow = ColdFlow { emit in
            for value in testValues {
                await emit(value)
            }
        }
        
        var collected = [String]()
        for await value in flow {
            collected.append(value)
        }
        
        #expect(collected == testValues)
    }
    
    @Test("Cold Flow Emits No Values")
    func testEmptyFlow() async {
        let flow = ColdFlow<String> { _ in }
        var collected = [String]()
        for await value in flow {
            collected.append(value)
        }
        #expect(collected.isEmpty)
    }
    
    @Test("Cold Flow Emits Single Value")
    func testSingleValue() async {
        let flow = ColdFlow { emit in
            await emit("OnlyOne")
        }
        var collected = [String]()
        for await value in flow {
            collected.append(value)
        }
        #expect(collected == ["OnlyOne"])
    }
    
    @Test("Cold Flow Handles Buffer Overflow")
    func testBufferOverflow() async {
        let values = Array(0...10)
        let flow = ColdFlow { emit in
            for value in values {
                await emit(value)
            }
        }
        var collected = [Int]()
        for await value in flow {
            collected.append(value)
        }
        #expect(collected == values)
    }
    
    @Test("Cold Flow is Cold (New Iterator Restarts)")
    func testColdness() async {
        let testValues = ["A", "B"]
        let flow = ColdFlow { emit in
            for value in testValues {
                await emit(value)
            }
        }
        var first = [String]()
        for await value in flow {
            first.append(value)
        }
        var second = [String]()
        for await value in flow {
            second.append(value)
        }
        #expect(first == testValues)
        #expect(second == testValues)
    }
}
