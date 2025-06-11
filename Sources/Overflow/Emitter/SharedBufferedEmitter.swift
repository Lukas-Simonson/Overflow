//
//  BufferedEmitter.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

/// A protocol representing a subscription to a shared buffered emitter, providing asynchronous iteration over emitted values.
///
/// Each subscription is uniquely identified and associated with a specific emitter. Subscriptions can register themselves,
/// cancel their subscription, and asynchronously receive values as they become available.
///
/// - Parameter Emitter: The emitter type this subscription is bound to, which must conform to `SharedBufferedEmitter`.
protocol SharedBufferedSubscription: Identifiable, AnyObject, Sendable, AsyncIteratorProtocol {
    associatedtype Emitter: SharedBufferedEmitter
    
    /// The unique identifier for this subscription.
    var id: UUID { get }
    
    /// The emitter instance this subscription is bound to.
    var emitter: Emitter { get }
    
    /// Cancels the subscription and cleans up resources on the emitter.
    func cancel() async
    
    /// Registers the subscription with the emitter, creating a buffer if needed.
    func register() async
}

/// An actor protocol for emitting and buffering asynchronous values to multiple uniquely identified subscribers.
///
/// Each subscriber has its own buffer, supports back-pressure via `maxBufferSize`, and coordinates delivery using continuations.
///
/// Conforming types can register/cancel subscriptions, emit values, and allow subscribers to await the next value.
///
/// - Parameter Element: The type of values emitted and buffered.
/// - Parameter Subscription: The subscription type, which must conform to `SharedBufferedSubscription`.
protocol SharedBufferedEmitter: Actor {
    
    associatedtype Element: Sendable
    associatedtype Subscription: SharedBufferedSubscription
    
    /// The maximum number of elements allowed in each subscriber's buffer.
    var maxBufferSize: Int { get }
    
    /// Continuations for handling buffer overflows per subscriber.
    var overflowContinuations: [UUID: [CheckedContinuation<Void, Never>]] { get set }
    
    /// Continuations for awaiting the next value per subscription.
    var waitingSubscriptions: [UUID: CheckedContinuation<Element, any Error>] { get set }
    
    /// Buffers holding emitted elements for each subscription.
    var buffers: [UUID: WeakBuffer<Subscription, Element>] { get set }
    
    /// Registers a subscription, creating a buffer if needed.
    func register(_ subscription: Subscription)
    
    /// Cancels a subscription and cleans up its resources.
    func cancel(id: UUID)
    
    /// Emits a new value to all active subscribers.
    func emit(_ newValue: Element) async
    
    /// Suspends until the next value is available for the given subscription.
    func awaitNextValue(id: UUID) async throws -> Element
}

// MARK: Default Implementations
extension SharedBufferedEmitter {
    
    /// Registers a subscription, creating a buffer if needed.
    ///
    /// Calls the default implementation `_register(_:)`.
    func register(_ subscription: Subscription) {
        _register(subscription)
    }
    
    /// Default implementation for registering a subscription.
    /// Initializes a buffer for the subscription if one does not exist.
    func _register(_ subscription: Subscription) {
        if buffers[subscription.id] == nil {
            buffers[subscription.id] = WeakBuffer(key: subscription, buffer: [])
        }
    }
    
    /// Cancels a subscription and cleans up its resources.
    ///
    /// Calls the default implementation `_cancel(id:)`.
    func cancel(id: UUID) {
        _cancel(id: id)
    }
    
    /// Default implementation for cancelling a subscription.
    /// Removes the buffer and resumes any waiting continuation with an error.
    func _cancel(id: UUID) {
        buffers.removeValue(forKey: id)
        let ws = waitingSubscriptions.removeValue(forKey: id)
        ws?.resume(throwing: ContinuationError.continuationOwnerExitedScope)
    }
    
    /// Emits a new value to all active subscribers.
    ///
    /// Calls the default implementation `_emit(_:)`.
    ///
    /// - Parameter newValue: The value to emit.
    func emit(_ newValue: Element) async {
        await _emit(newValue)
    }
    
    /// Default implementation for emitting a value to all subscribers.
    ///
    /// Handles buffer management, continuations, and back-pressure for each subscription.
    ///
    /// - Parameter newValue: The value to emit.
    func _emit(_ newValue: Element) async {
        for id in buffers.keys {
            guard var buffer = buffers[id] else { continue }
            
            // Remove buffer is Subscription has left scope.
            if buffer.isCleared {
                cancel(id: id)
            }
            
            // Handle any current continuations before adding to buffer.
            else if let ws = waitingSubscriptions.removeValue(forKey: id) {
                // No values should be in buffer; however, if there are, emit the first buffered value, then update the buffer.
                if let buffed = buffer.removeFirst() {
                    ws.resume(returning: buffed)
                    buffer.append(newValue)
                    buffers[id] = buffer // Update buffers with updated buffer.
                } else {
                    // Continue the waiting subscription without adding to buffer.
                    ws.resume(returning: newValue)
                }
            }
            
            // If the buffer is needed, add value to the buffer.
            else {
                buffer.append(newValue)
                buffers[id] = buffer // Update buffers with updated buffer.
                
                // Handle buffer overflow
                if buffer.size > maxBufferSize {
                    await withCheckedContinuation { cont in
                        overflowContinuations[id, default: []].append(cont)
                    }
                }
            }
        }
    }
    
    /// Suspends until the next value is available for the given subscription.
    ///
    /// Calls the default implementation `_awaitNextValue(id:)`.
    ///
    /// - Parameter id: The unique identifier for the subscription.
    /// - Returns: The next value for the subscription.
    func awaitNextValue(id: UUID) async throws -> Element {
        try await _awaitNextValue(id: id)
    }
    
    /// Default implementation for awaiting the next value for a subscription.
    /// Returns the next buffered value if available, or suspends until a value is emitted.
    ///
    /// - Parameter id: The unique identifier for the subscription.
    /// - Returns: The next value for the subscription.
    func _awaitNextValue(id: UUID) async throws -> Element {
        if var buffer = buffers[id], let first = buffer.removeFirst() {
            buffers[id] = buffer // Update buffer with removed value
            
            if var conts = overflowContinuations[id], !conts.isEmpty {
                conts.removeFirst().resume()
                overflowContinuations[id] = conts.isEmpty ? nil : conts
            }
            
            return first
        }
        
        guard waitingSubscriptions[id] == nil
        else { fatalError("Continuation not called before being removed") }
        
        // No Buffer, await next value
        return try await withCheckedThrowingContinuation { cont in
            waitingSubscriptions[id] = cont
        }
    }
}
