//
//  SharedPublisher.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

protocol SharedPublisher: Actor, Publisher {
    var subscribers: [UUID: Weak<Sub>] { get set }
}

extension SharedPublisher {
    func emit(_ newValue: Element) async {
        for id in subscribers.keys {
            if let sub = subscribers[id]?.value {
                await sub.send(newValue)
            } else {
                subscribers.removeValue(forKey: id)
            }
        }
    }
    
    func register(_ subscriber: Sub) async {
        subscribers[subscriber.id] = Weak(subscriber)
    }
    
    func cancel(id: UUID) async {
        await subscribers.removeValue(forKey: id)?.value?.close()
    }
}
