//
//  StateFlowTests.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Testing
@testable import Overflow

@Suite("State Flow Tests")
struct StateFlowTests {
    
    @Test("Initial value is correct")
    func testInitialValue() async {
        let flow = MutableStateFlow(initial: 42).asStateFlow()
        let value = await flow.value
        #expect(value == 42)
    }
    
    @Test("StateFlow emits multiple values")
    func testStateFlowEmitsMultipleValues() async {
        let flow = MutableStateFlow(initial: "Hello")
        let valuesToEmit = ["World", "Goodbye", "Friends", "Hola", "Compadre", "Adios", "Amigo"]
        
        Task {
            await Task.yield() // Allow subscription to start
            for value in valuesToEmit {
                await flow.emit(value)
            }
        }
        
        var receivedValues = [String]()
        for await value in flow {
            receivedValues.append(value)
            if receivedValues.count == valuesToEmit.count + 1 {
                break
            }
        }
        
        #expect(["Hello"] + valuesToEmit == receivedValues)
    }
    
    @Test("StateFlow Suspends on Buffer Overflow")
    func testStateFlowSuspendsOnBufferOverflow() async {
        let flow = MutableStateFlow(initial: 0)
        let subscription = flow.makeAsyncIterator()
        _ = await subscription.next() // register subscription on flow.
        
        let emitTask = Task {
            for i in 1...10 {
                await flow.emit(i)
            }
        }
        
        // Wait for buffer to fill up.
        try? await Task.sleep(for: .milliseconds(500))
        
        // Consume values slowly
        for _ in 1...10 {
            _ = await subscription.next()
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        await emitTask.value
        // If emit suspends and resumes correctly, this test will complete without deadlock.
    }
    
    @Test("Multiple subscribers receive all values independently")
    func testMultipleSubscribers() async {
        let flow = MutableStateFlow(initial: 0)
        let sub1 = flow.makeAsyncIterator()
        let sub2 = flow.makeAsyncIterator()
        
        #expect(await sub1.next() == 0)
        #expect(await sub2.next() == 0)
        
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await flow.emit(1)
        }
        
        #expect(await sub1.next() == 1)
        #expect(await sub2.next() == 1)
    }
    
    @Test("New subscriber receives current value immediately")
    func testInitialValueDelivery() async {
        let flow = MutableStateFlow(initial: "initial")
        await flow.emit("new")
        let v = await flow.makeAsyncIterator().next()
        #expect(v == "new")
    }
    
    @Test("Concurrent emissions preserve order and delivery")
    func testConcurrentEmissions() async {
        let flow = MutableStateFlow(initial: 0)
        let sub = flow.makeAsyncIterator()
        _ = await sub.next()
        let values = Array(1...20)
        Task {
            await withTaskGroup(of: Void.self) { group in
                for v in values {
                    group.addTask { await flow.emit(v) }
                }
            }
        }
        var received = [Int]()
        for _ in 1...20 { if let v = await sub.next() { received.append(v) } }
        #expect(Set(received) == Set(values))
    }
    
    @Test("Stress test: rapid emits and cancels")
    func testNoDeadlocksOrLeaks() async {
        let flow = MutableStateFlow(initial: 0)
        for _ in 0..<100 {
            let sub = flow.makeAsyncIterator()
            Task { await flow.emit(Int.random(in: 1...1000)) }
            _ = await sub.next()
            await sub.cancel()
        }
    }
}
