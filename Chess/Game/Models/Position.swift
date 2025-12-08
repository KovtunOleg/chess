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
    
    var isLight: Bool {
        (rank + file) % 2 == 1
    }
}

extension Position: CustomStringConvertible {
    var description: String {
        file.fileString + rank.rankString
    }
}

extension Int {
    var rankString: String {
        "\(self + 1)"
    }
    var fileString: String {
        let letter = UnicodeScalar("a").value + UInt32(self)
        return String(UnicodeScalar(letter)!)
    }
}
