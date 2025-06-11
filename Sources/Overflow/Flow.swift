//
//  Flow.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

protocol Flow: Sendable, AsyncSequence where Element: Sendable { }


protocol MutableFlow: Flow, Sendable, AsyncSequence where Element: Sendable {
    func emit(_ value: Element) async
}

extension MutableFlow {
    func emit(_ value: Element) {
        Task { emit(value) }
    }
}
