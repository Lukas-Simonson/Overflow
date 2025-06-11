//
//  Flow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

public protocol Flow: Sendable, AsyncSequence where Element: Sendable { }

public protocol MutableFlow: Flow, Sendable, AsyncSequence where Element: Sendable {
    func emit(_ value: Element) async
}

public extension MutableFlow {
    func emit(_ value: Element) {
        Task { emit(value) }
    }
}
