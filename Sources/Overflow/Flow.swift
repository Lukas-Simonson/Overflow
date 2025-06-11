//
//  Flow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Dispatch

public protocol Flow: Sendable, AsyncSequence where Element: Sendable {
    
}

public protocol MutableFlow: Flow, Sendable, AsyncSequence where Element: Sendable {
    func emit(_ value: Element) async
}

public extension MutableFlow {
    func emit(_ value: Element) {
        Task { emit(value) }
    }
}

public extension AsyncSequence where Self: Sendable, Element: Sendable {

    func collect(
        on queue: DispatchQueue,
        taskPriority: TaskPriority? = nil,
        _ collector: @Sendable @escaping (Element) -> Void
    ) {
        Task(priority: taskPriority) {
            for try await element in self {
                queue.async {
                    collector(element)
                }
            }
        }
    }
}
