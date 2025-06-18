//
//  Flow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Dispatch

/// A protocol representing an asynchronous, sendable sequence of values.
///
/// Types conforming to `Flow` can be iterated asynchronously and guarantee that their elements are `Sendable`.
public protocol Flow: Sendable, AsyncSequence where Element: Sendable {
    
}

/// A protocol for mutable flows, allowing emission of new values into the sequence.
///
/// Extends `Flow` and requires an async `emit` function.
public protocol MutableFlow: Flow, Sendable, AsyncSequence where Element: Sendable {
    
    /// Emits a new value into the flow.
    ///
    /// - Parameter value: The value to emit.
    func emit(_ value: Element) async
}

public extension MutableFlow {
    
    /// Emits a value asynchronously in a detached task.
    ///
    /// - Parameter value: The value to emit.
    func emitDeferred(_ value: Element) {
        Task { await emit(value) }
    }
}

public extension AsyncSequence where Self: Sendable, Element: Sendable {

    /// Collects elements from the sequence and delivers them to the provided closure on the specified dispatch queue.
    ///
    /// The collection runs in a new task, and each element is dispatched to the queue as it arrives.
    ///
    /// - Parameters:
    ///   - queue: The `DispatchQueue` on which to execute the collector closure.
    ///   - taskPriority: Optional priority for the collection task.
    ///   - collector: Closure to handle each collected element.
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
