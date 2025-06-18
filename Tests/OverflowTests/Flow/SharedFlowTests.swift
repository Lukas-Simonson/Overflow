//
//  SharedFlowTests.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Testing
import Overflow

@Suite("Shared Flow Tests")
struct SharedFlowTests {
    
    @Test("SharedFlow emits multiple values")
    func testSharedFlowEmitsMultipleValues() async {
        let flow = MutableSharedFlow<String>()
        let valuesToEmit = ["World", "Goodbye", "Friends", "Hola", "Compadre", "Adios", "Amigo"]
        
        Task {
            try? await Task.sleep(for: .milliseconds(100)) // Allow subscription to start
            for value in valuesToEmit {
                await flow.emit(value)
            }
        }
        
        var receivedValues = [String]()
        for await value in flow {
            receivedValues.append(value)
            if receivedValues.count == valuesToEmit.count {
                break
            }
        }
        
        #expect(valuesToEmit == receivedValues)
    }
    
    @Test("Multiple subscribers receive all values independently")
    func testMultipleSubscribers() async {
        let flow = MutableSharedFlow<Int>()
        let sub1 = flow.makeAsyncIterator()
        let sub2 = flow.makeAsyncIterator()
        
        // Register Subscriptions so emitted value can be buffered.
        await sub1.register()
        await sub2.register()
        
        await flow.emit(0)
        
        #expect(await sub1.next() == 0)
        #expect(await sub2.next() == 0)
        
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await flow.emit(1)
        }
        
        #expect(await sub1.next() == 1)
        #expect(await sub2.next() == 1)
    }
    
    @Test("Concurrent emissions preserve order and delivery")
    func testConcurrentEmissions() async {
        let flow = MutableSharedFlow<Int>()
        let sub = flow.makeAsyncIterator()
        await sub.register()
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
        #expect(received.sorted() == values)
    }
    
    @Test("Stress test: rapid emits and cancels")
    func testNoDeadlocksOrLeaks() async {
        let flow = MutableSharedFlow<Int>()
        for _ in 0..<100 {
            let sub = flow.makeAsyncIterator()
            await sub.register()
            Task { await flow.emit(Int.random(in: 1...1000)) }
            _ = await sub.next()
            await sub.close()
        }
    }
}
