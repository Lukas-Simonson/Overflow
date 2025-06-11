//
//  BufferedEmitter.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/10/25.
//

import Foundation

protocol SharedBufferedSubscription: Identifiable, AnyObject, Sendable, AsyncIteratorProtocol {
    var id: UUID { get }
    
    func cancel() async
}

protocol SharedBufferedEmitter: Actor {
    associatedtype Element: Sendable
    associatedtype Subscription: SharedBufferedSubscription
    
    var maxBufferSize: Int { get }
    var overflowContinuations: [UUID: [CheckedContinuation<Void, Never>]] { get set }
    
    var waitingSubscriptions: [UUID: CheckedContinuation<Element, any Error>] { get set }
    var buffers: [UUID: WeakBuffer<Subscription, Element>] { get set }
    
    func register(_ subscription: Subscription)
    func cancel(id: UUID)
    
    func emit(_ newValue: Element) async
    func awaitNextValue(id: UUID) async throws -> Element
}

// MARK: Default Implementations
extension SharedBufferedEmitter {
    func register(_ subscription: Subscription) {
        _register(subscription)
    }
    
    func _register(_ subscription: Subscription) {
        if buffers[subscription.id] == nil {
            buffers[subscription.id] = WeakBuffer(key: subscription, buffer: [])
        }
    }
    
    func cancel(id: UUID) {
        _cancel(id: id)
    }
    
    func _cancel(id: UUID) {
        buffers.removeValue(forKey: id)
        let ws = waitingSubscriptions.removeValue(forKey: id)
        ws?.resume(throwing: ContinuationError.continuationOwnerExitedScope)
    }
    
    func emit(_ newValue: Element) async {
        await _emit(newValue)
    }
    
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
    
    func awaitNextValue(id: UUID) async throws -> Element {
        try await _awaitNextValue(id: id)
    }
    
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
