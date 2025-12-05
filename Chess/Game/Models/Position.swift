//
//  Position.swift
//  Chess
//
//  Created by Oleg Kovtun on 01.12.2025.
//

struct Position: Hashable {
    private(set) var rank: Int
    private(set) var file: Int
    
    var isValid: Bool {
        rank >= 0 && rank < Game.size && file >= 0 && file < Game.size
    }
}
