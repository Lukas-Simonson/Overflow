//
//  BufferedEmitter.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

/// A protocol representing a subscription to a buffered emitter, providing asynchronous iteration over emitted values.
///
/// Conforming types must specify the associated `Emitter` type, which must conform to `BufferedEmitter` and emit the same `Element` type.
///
/// The subscription acts as an async iterator, allowing consumers to receive values as they become available.
///
/// - Parameter Emitter: The emitter type this subscription is bound to.
/// - Parameter Element: The type of values emitted and received.
protocol BufferedSubscription: Sendable, AsyncIteratorProtocol {
    associatedtype Emitter: BufferedEmitter where Emitter.Element == Self.Element
    
    /// The emitter instance this subscription is bound to.
    var emitter: Emitter { get }
}

/// An actor protocol for emitting and buffering asynchronous values to subscribers.
///
/// Maintains a buffer of values, supports back-pressure via `maxBufferSize`, and coordinates delivery using continuations.
///
/// Conforming types can emit values, close the stream, and allow subscribers to await the next value.
///
/// - Parameter Element: The type of values emitted and buffered.
public protocol BufferedEmitter: Actor {
    
    /// The type of values emitted by the emitter.
    associatedtype Element: Sendable
    
    /// The maximum number of elements allowed in the buffer.
    var maxBufferSize: Int { get }
    
    /// The buffer holding pending elements for subscribers.
    var buffer: [Element] { get set }
    
    /// The continuation used to resume a subscriber waiting for the next value.
    var continuation: CheckedContinuation<Element?, any Error>? { get set }
    
    /// Emits a new value to the buffer or directly to a waiting subscriber.
    /// - Parameter newValue: The value to emit.
    func emit(_ newValue: Element) async
    
    /// Closes the emitter, signaling no more values will be emitted.
    func close() async
    
    /// Suspends until the next value is available or the emitter is closed.
    /// - Returns: The next value, or nil if closed.
    func awaitNextValue() async throws -> Element?
}

// MARK: Default Implementations
public extension BufferedEmitter {
    
    /// Emits a new value to the buffer or directly to a waiting subscriber.
    ///
    /// Calls the default implementation `_emit(_:)`.
    ///
    /// - Parameter newValue: The value to emit.
    func emit(_ newValue: Element) async {
        await _emit(newValue)
    }
    
    /// Default implementation for emitting a value.
    ///
    /// If a subscriber is waiting, delivers the value immediately.
    /// Otherwise, appends the value to the buffer, respecting `maxBufferSize`.
    ///
    /// - Parameter newValue: The value to emit.
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
    
    /// Suspends until the next value is available or the emitter is closed.
    ///
    /// Calls the default implementation `_awaitNextValue()`.
    ///
    /// - Returns: The next value, or nil if closed.
    func awaitNextValue() async throws -> Element? {
        try await _awaitNextValue()
    }
    
    /// Default implementation for awaiting the next value.
    ///
    /// Returns the next buffered value if available, or suspends until a value is emitted or the emitter is closed.
    ///
    /// - Returns: The next value, or nil if closed.
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
    
    /// Closes the emitter, signaling no more values will be emitted.
    ///
    /// Calls the default implementation `_close()`.
    func close() async {
        await _close()
    }
    
    /// Default implementation for closing the emitter.
    ///
    /// Resumes any waiting subscriber with nil if the buffer is empty.
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
