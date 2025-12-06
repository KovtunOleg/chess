//
//  Notation.swift
//  Chess
//
//  Created by Oleg Kovtun on 04.12.2025.
//

protocol NotationDelegate {
    func notation(_ notation: Notation, didAddMove move: Notation.Move)
    func notation(_ notation: Notation, willPromote: (Piece) -> Piece)
}

struct Notation {
    enum Move {
        case unknown // used for FEN format
        case move(piece: Piece, to: Position)
        case capture(piece: Piece, captured: Piece)
        case castle(king: Piece, rook: Piece, short: Bool)
        case promote(pawn: Piece, promoted: Piece, isCheck: Bool, isMate: Bool, isStalemate: Bool)
        case check(piece: Piece)
        case mate(piece: Piece)
        case stalemate(piece: Piece)
    }
    
    private(set) var moves: [Move]
    
    var delegate: NotationDelegate?
    
    var halfMoves: Int { moves.count }
    var fullMoves: Int { Int((Double(halfMoves) / 2.0).rounded(.up)) }
    
    init(moves: [Move] = []) {
        self.moves = moves
    }
    
    mutating func append(_ move: Move) {
        moves.append(move)
        delegate?.notation(self, didAddMove: move)
    }
}
