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
    
    let elementCount = 1_000
    let tolerance = 0
    let sharedSubscribers = 10
    
    @Test("MutableSharedFlow High Pressure", .timeLimit(.minutes(1)))
    func mutableSharedFlowHighPressure() async throws {
        let flow = MutableSharedFlow<Int>(bufferPolicy: .stalling(maxSize: 5))
        
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
}
