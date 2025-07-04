//
//  Publisher.swift
//  Overflow
//
//  Created by Lukas Simonson on 6/12/25.
//

import Foundation

public protocol Publisher: Sendable, Actor {
    associatedtype Element: Sendable
    associatedtype Sub: Subscriber where Sub.Element == Element
    
    func emit(_ newValue: Element) async
    func register(_ subscriber: Sub) async
}

