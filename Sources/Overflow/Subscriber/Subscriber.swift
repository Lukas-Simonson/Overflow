//
//  Subscriber.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

public protocol Subscriber: AnyObject, Sendable, AsyncIteratorProtocol where Element: Sendable {
    
    var id: UUID { get }
    
    func send(_ value: Element) async
    func close() async
}


