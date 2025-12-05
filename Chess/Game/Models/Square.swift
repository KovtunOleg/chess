//
//  Square.swift
//  Chess
//
//  Created by Oleg Kovtun on 03.12.2025.
//


import SwiftUI
import Observation

@Observable
class Square {
    private(set) var position: Position
    var piece: Piece? {
        didSet {
            piece?.position = position
        }
    }
    
    init(position: Position) {
        self.position = position
    }
}

extension Square: Hashable {
    static func == (lhs: Square, rhs: Square) -> Bool {
        lhs.position == rhs.position
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(position)
    }
}

extension Array where Element == [Square] {
    var pieces: [Piece] {
        flatMap { $0 }
            .compactMap { $0.piece }
    }
    
    static var empty: [[Square]] {
        var board = [[Square]]()
        for rank in 0..<Game.size {
            var row = [Square]()
            for file in 0..<Game.size {
                row.append(Square(position: Position(rank: rank, file: file)))
            }
            board.append(row)
        }
        return board
    }
    
    var copy: [[Square]] {
        let copy = [[Square]].empty
        for piece in pieces {
            guard let position = piece.position else { continue }
            let square = copy[position.rank][position.file]
            square.piece = piece.copy
        }
        return copy
    }
}
