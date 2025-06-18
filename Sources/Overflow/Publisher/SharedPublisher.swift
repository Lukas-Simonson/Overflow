//
//  SharedPublisher.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

protocol SharedPublisher: Publisher {
    var subscribers: [UUID: Weak<Sub>] { get set }
    
    var isEmitting: Bool { get set }
    var emissionQueue: [Element] { get set }
    
    func cancel(id: UUID) async
}

extension SharedPublisher {
    func emit(_ newValue: Element) async {
        await _emit(newValue)
    }
    
    func processEmissions() async {
        guard !isEmitting else {
            return
        }
        isEmitting = true
        
        while !emissionQueue.isEmpty {
            let value = emissionQueue.removeFirst()
            for id in subscribers.keys {
                if let sub = subscribers[id]?.value {
                    await sub.send(value)
                } else {
                    subscribers.removeValue(forKey: id)
                }
            }
        }
        isEmitting = false
    }
    
    func _emit(_ newValue: Element) async {
        emissionQueue.append(newValue)
        await processEmissions()
    }
    
    func register(_ subscriber: Sub) async {
        subscribers[subscriber.id] = Weak(subscriber)
    }
    
    func cancel(id: UUID) async {
        await subscribers.removeValue(forKey: id)?.value?.close()
    }
}
