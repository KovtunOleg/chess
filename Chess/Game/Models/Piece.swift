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
    
    var value: Int {
        guard let position else { return 0 }
        let index = position.rank * Game.size + position.file
        switch type {
        case .king: return 0 + Self.kingExtraWeightsMap[color == .white ? index : Game.squaresCount - index - 1]
        case .queen: return 900 + Self.queenExtraWeightsMap[color == .white ? index : Game.squaresCount - index - 1]
        case .rook: return 500 + Self.rookExtraWeightsMap[color == .white ? index : Game.squaresCount - index - 1]
        case .bishop: return 300 + Self.bishopExtraWeightsMap[color == .white ? index : Game.squaresCount - index - 1]
        case .knight: return 300 + Self.knightExtraWeightsMap[color == .white ? index : Game.squaresCount - index - 1]
        case .pawn: return 100 + Self.pawnExtraWeightsMap[color == .white ? index : Game.squaresCount - index - 1]
        }
    }
    
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

extension Piece: Comparable {
    static let order: [Piece.`Type`] = [.pawn, .knight, .bishop, .rook, .queen, .king]
    static func < (lhs: Piece, rhs: Piece) -> Bool {
        Self.order.firstIndex(of: lhs.type)! < Self.order.firstIndex(of: rhs.type)!
    }
}

extension Piece {
    static let pgnMap = `Type`.allCases.reduce(into: [:]) { $0[$1.description] = $1 }
    
    enum `Type`: Hashable, CustomStringConvertible, CaseIterable {
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
    enum Color: Hashable, CaseIterable, CustomStringConvertible, Codable {
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
    
    func description(shortenFile: Bool, shortenRank: Bool) -> String {
        guard let position, shortenFile || shortenRank else { return description }
        var description = type.description
        if shortenFile || shortenRank {
            if !shortenFile { description += position.file.fileString }
            if !shortenRank { description += position.rank.rankString }
        }
        return description
    }
}

extension Piece: Hashable {
    static func == (lhs: Piece, rhs: Piece) -> Bool {
        lhs.type == rhs.type && lhs.color == rhs.color && lhs.position == rhs.position
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(color)
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
    
    private static let pawnExtraWeightsMap = [
        0,  0,  0,  0,  0,  0,  0,  0,
        5, 10, 10,-20,-20, 10, 10,  5,
        5, -5,-10,  0,  0,-10, -5,  5,
        0,  0,  0, 20, 20,  0,  0,  0,
        5,  5, 10, 25, 25, 10,  5,  5,
        10, 10, 20, 30, 30, 20, 10, 10,
        50, 50, 50, 50, 50, 50, 50, 50,
        0,  0,  0,  0,  0,  0,  0,  0
    ]
    private static let knightExtraWeightsMap = [
        -50,-40,-30,-30,-30,-30,-40,-50,
         -40,-20,  0,  5,  5,  0,-20,-40,
         -30,  5, 10, 15, 15, 10,  5,-30,
         -30,  0, 15, 20, 20, 15,  0,-30,
         -30,  5, 15, 20, 20, 15,  5,-30,
         -30,  0, 10, 15, 15, 10,  0,-30,
         -40,-20,  0,  0,  0,  0,-20,-40,
         -50,-40,-30,-30,-30,-30,-40,-50
    ]
    
    private static let bishopExtraWeightsMap = [
        -20,-10,-10,-10,-10,-10,-10,-20,
         -10,  5,  0,  0,  0,  0,  5,-10,
         -10, 10, 10, 10, 10, 10, 10,-10,
         -10,  0, 10, 10, 10, 10,  0,-10,
         -10,  5,  5, 10, 10,  5,  5,-10,
         -10,  0,  5, 10, 10,  5,  0,-10,
         -10,  0,  0,  0,  0,  0,  0,-10,
         -20,-10,-10,-10,-10,-10,-10,-20
    ]
    private static let rookExtraWeightsMap = [
        0,  0,  5,  10, 10, 5,  0,  0,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        -5,  0,  0,  0,  0,  0,  0, -5,
        5,  10, 10, 10, 10, 10, 10, 5,
        0,  0,  0,  0,  0,  0,  0,  0,
    ]
    private static let queenExtraWeightsMap = [
        -20,-10,-10, -5, -5,-10,-10,-20,
         -10,  0,  5,  0,  0,  0,  0,-10,
         -10,  5,  5,  5,  5,  5,  0,-10,
         0,  0,  5,  5,  5,  5,  0, -5,
         -5,  0,  5,  5,  5,  5,  0, -5,
         -10,  0,  5,  5,  5,  5,  0,-10,
         -10,  0,  0,  0,  0,  0,  0,-10,
         -20,-10,-10, -5, -5,-10,-10,-20,
    ]
    private static let kingExtraWeightsMap = [
        20,  30,  10,  0,   0,   10,  30,  20,
        20,  20,  0,   0,   0,   0,   20,  20,
        -10, -20, -20, -20, -20, -20, -20, -10,
        -20, -30, -30, -40, -40, -30, -30, -20,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
    ]
}
