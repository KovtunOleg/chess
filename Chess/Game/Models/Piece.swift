//
//  Figure.swift
//  Chess
//
//  Created by Oleg Kovtun on 01.12.2025.
//

import SwiftUI

@Observable
class Piece {
    private(set) var color: Piece.Color
    private(set) var type: Piece.`Type`
    
    var dragPosition = CGPoint.zero
    var movesCount: Int
    var position: Position?
    
    var copy: Piece {
        Piece(color: color, type: type, position: position, movesCount: movesCount)
    }
    
    init(color: Piece.Color, type: Piece.`Type`, position: Position? = nil, movesCount: Int = 0) {
        self.color = color
        self.type = type
        self.position = position
        self.movesCount = movesCount
    }
}

extension Piece {
    enum `Type`: Hashable, CustomStringConvertible {
        case king, queen, rook, bishop, knight, pawn
        
        var description: String {
            switch self {
            case .queen: return "Q"
            case .king: return "K"
            case .rook: return "R"
            case .bishop: return "B"
            case .knight: return "N"
            default: return ""
            }
        }
    }
    enum Color: Hashable, CustomStringConvertible {
        case white, black
        
        var description: String {
            switch self {
            case .white: return "w"
            case .black: return "b"
            }
        }
        
        mutating func toggle() {
            switch self {
            case .white: self = .black
            case .black: self = .white
            }
        }
    }
}

extension Piece: CustomStringConvertible {
    var description: String {
        guard let position else { return type.description }
        return "\(type.description)\(position.description)"
    }
}

extension Piece: Hashable {
    static func == (lhs: Piece, rhs: Piece) -> Bool {
        lhs.type == rhs.type && lhs.color == rhs.color && lhs.position == rhs.position
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(color)
        hasher.combine(type)
        hasher.combine(position)
    }
}

extension Piece {
    var image: ImageResource {
        switch (color, type) {
        case (.white, .king): return .whiteKing
        case (.black, .king): return .blackKing
        case (.white, .queen): return .whiteQueen
        case (.black, .queen): return .blackQueen
        case (.white, .rook): return .whiteRook
        case (.black, .rook): return .blackRook
        case (.white, .bishop): return .whiteBishop
        case (.black, .bishop): return .blackBishop
        case (.white, .knight): return .whiteKnight
        case (.black, .knight): return .blackKnight
        case (.white, .pawn): return .whitePawn
        case (.black, .pawn): return .blackPawn
        }
    }
    
    var directions: [[Int]] {
        switch type {
        case .king, .queen: return [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]
        case .rook: return [[-1, 0], [0, -1], [0, 1], [1, 0]]
        case .bishop: return [[-1, -1], [-1, 1], [1, -1], [1, 1]]
        case .pawn:
            switch color {
            case .white: return [[1, 0]]
            case .black: return [[-1, 0]]
            }
        case .knight: return [[-2,-1],[-2,1],[2,-1],[2,1],[-1,2],[1,2],[-1,-2],[1,-2]]
        }
    }
    
    var limit: Int {
        switch type {
        case .king, .knight: return 1
        case .pawn: return movesCount == 0 ? 2 : 1
        default: return Game.size - 1
        }
    }
}
