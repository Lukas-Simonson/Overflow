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
    
    @Test
    func test() async {
        let flow = ColdFlow { e in
            await e.emit("Hello")
            try? await Task.sleep(for: .seconds(0.5))
            await e.emit("World")
        }
        
        for i in 1...10 {
            for await value in flow {
                print("\(value) \(i)")
            }
        }
    }
}
