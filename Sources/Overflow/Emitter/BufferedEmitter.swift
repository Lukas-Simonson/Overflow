//
//  BufferedEmitter.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

protocol BufferedSubscription: Sendable, AsyncIteratorProtocol {
    associatedtype Emitter: BufferedEmitter where Emitter.Element == Self.Element
    
    var emitter: Emitter { get }
}

public protocol BufferedEmitter: Actor {
    associatedtype Element: Sendable
    
    var maxBufferSize: Int { get }
    var buffer: [Element] { get set }
    
    var continuation: CheckedContinuation<Element?, any Error>? { get set }
    
    func emit(_ newValue: Element) async
    func close() async
    func awaitNextValue() async throws -> Element?
}

// MARK: Default Implementations
public extension BufferedEmitter {
    func emit(_ newValue: Element) async {
        await _emit(newValue)
    }
    
    func _emit(_ newValue: Element) async {
        if let continuation {
            if buffer.isEmpty {
                continuation.resume(returning: newValue)
            } else {
                // Should be redundant
                continuation.resume(returning: buffer.removeFirst())
            }
            self.continuation = nil
        } else {
            while buffer.count > maxBufferSize {
                await Task.yield()
            }
            buffer.append(newValue)
        }
    }
    
    func awaitNextValue() async throws -> Element? {
        try await _awaitNextValue()
    }
    
    func _awaitNextValue() async throws -> Element? {
        if !buffer.isEmpty {
            return buffer.removeFirst()
        }
        
        guard continuation == nil
        else { fatalError("Continuation not called before being removed") }
        
        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
        }
    }
    
    func close() async {
        await _close()
    }
    
    func _close() async {
        while true {
            if let continuation, buffer.isEmpty {
                continuation.resume(returning: nil)
                break
            }
            await Task.yield()
        }
    }
}

extension BufferedSubscription {
    func next() async throws -> Element? {
        try? await emitter.awaitNextValue()
    }
}
