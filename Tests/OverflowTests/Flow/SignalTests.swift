//
//  SignalTests.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Testing
import XCTest
@preconcurrency import Combine
@testable import Overflow


@Suite("High Pressure Flow Testing")
struct PressureTest {
    
    let elementCount = 100_000
    let tolerance = 0
    let sharedSubscribers = 10
    
    @Test("Mutable Signal High Pressure", .timeLimit(.minutes(1)))
    func mutableSignalHighPressure() async throws {
        let flow = MutableSignalFlow<Int>(bufferPolicy: .stalling(maxSize: 5))
        
        await withTaskGroup(of: Void.self) { group in
            
            for _ in 0..<sharedSubscribers {
                group.addTask {
                    var received = 0
                    for await _ in flow {
                        received += 1
                        if received >= elementCount - tolerance { break }
                    }
                }
            }
            
            group.addTask {
                try? await Task.sleep(for: .milliseconds(1)) // Allow flow to start being collected from
                for i in 0..<elementCount {
                    await flow.emit(i)
                    // try? await Task.sleep(for: .milliseconds(1))
                }
            }
        }
    }
    
    @Test("Combine High Pressure", .timeLimit(.minutes(1)))
    func combineHighPressure() async throws {
        let subject = PassthroughSubject<Int, Never>()
        // let flow = MutableStateFlow<Int>(initial: 0)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await Task.sleep(for: .seconds(1))
                for i in 0..<elementCount {
                    print("Sending \(i)")
                    subject.send(i)
                }
            }
            
            group.addTask {
                var received = 0
                
                var cont: CheckedContinuation<Void, Never>?
                
                let cancellable = subject
                    .eraseToAnyPublisher()
                    .sink { i in
                        print("Received \(i)")
                        received += 1
                        if received >= elementCount - tolerance {
                            cont?.resume()
                        }
                    }
                
                await withCheckedContinuation { c in
                    cont = c
                }
                
                cancellable.cancel()
            }
        }
    }
}

final class SignalPerformanceTests: XCTestCase {
    let elementCount = 10000
    
    let options = {
        let op = XCTMeasureOptions()
        op.iterationCount = 100
        return op
    }()
    
    let metrics: [XCTMetric] = [
        XCTCPUMetric(), XCTClockMetric(), XCTMemoryMetric()
    ]
    
    func testMutableSignalEmitterPerformance() async {
        let flow = MutableSignalFlow<Int>()
        let signal = flow.makeAsyncIterator()
        let count = elementCount
        
        measure(metrics: metrics, options: options) {
            let exp = expectation(description: "Finished")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try? await Task.sleep(for: .milliseconds(500))
                        for i in 0..<count {
                            await flow.emit(i)
                        }
                    }
                    
                    group.addTask {
                        var received = 0
                        while let _ = await signal.next() {
                            received += 1
                            if received == count { break }
                        }
                    }
                }
                
                exp.fulfill()
            }
            
            wait(for: [exp], timeout: 15)
        }
    }
    
    func testMutableSharedFlowPerformance() async {
        let subject = PassthroughSubject<Int, Never>()
        let count = elementCount
        
        measure(metrics: metrics, options: options) {
            let exp = expectation(description: "Finished")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try? await Task.sleep(for: .milliseconds(500))
                        for i in 0..<count {
                            subject.send(i)
                        }
                    }
                    
                    group.addTask {
                        var received = 0
                        
                        var cont: CheckedContinuation<Void, Never>?
                        
                        let cancellable = subject
                            .eraseToAnyPublisher()
                            .sink { i in
                                received += 1
                                if received >= count {
                                    cont?.resume()
                                }
                            }
                        
                        await withCheckedContinuation { c in
                            cont = c
                        }
                        
                        cancellable.cancel()
                    }
                }
                
                exp.fulfill()
            }
            
            wait(for: [exp], timeout: 15)
        }
    }
}
