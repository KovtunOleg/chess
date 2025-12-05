//
//  Notation.swift
//  Chess
//
//  Created by Oleg Kovtun on 04.12.2025.
//

protocol NotationDelegate {
    func notationDidChange(_ notation: Notation)
}

struct Notation {
    enum Move {
        case move(piece: Piece, to: Position)
        case capture(piece: Piece, captured: Piece)
        case castle(king: Piece, rook: Piece, short: Bool)
        case check(piece: Piece)
        case mate(piece: Piece)
        case stalemate(piece: Piece)
    }
    
    private(set) var moves = [Move]()
    
    var delegate: NotationDelegate?
    
    mutating func append(_ move: Move) {
        moves.append(move)
        delegate?.notationDidChange(self)
    }
}
