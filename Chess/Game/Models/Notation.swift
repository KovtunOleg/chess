//
//  Notation.swift
//  Chess
//
//  Created by Oleg Kovtun on 04.12.2025.
//

protocol NotationDelegate {
    func notation(_ notation: Notation, didAddMove move: Notation.Move, state: Notation.State)
}

struct Notation {
    enum Move: CustomStringConvertible {
        case unknown // used for FEN format
        case move(piece: Piece, to: Position, captured: Piece? = nil, promoted: Piece? = nil)
        case castle(king: Piece, rook: Piece, short: Bool)
        
        var description: String {
            switch self {
            case let .move(piece, position, captured, promoted):
                let capturedDescription = captured != nil ? "x" : ""
                let promotedDescription = promoted != nil ? "=\(promoted!.type.description)" : ""
                return "\(piece.description)\(capturedDescription)\(position.description)\(promotedDescription)"
            case let .castle(king, _, short):
                return "\(king.description) \(short ? "O-O" : "O-O-O")"
            default:
                return ""
            }
        }
    }
    
    enum State: Hashable, CustomStringConvertible {
        case play
        case check
        case mate(winner: Piece.Color)
        case draw
        
        var description: String {
            switch self {
            case .check: return "+"
            case let .mate(winner): return "# \(winner == .white ? "1-0" : "0-1")"
            case .draw: return " 1/2 - 1/2"
            default: return ""
            }
        }
    }
    
    private(set) var moves: [Move]
    private(set) var state: State
    
    var delegate: NotationDelegate?
    
    var halfMoves: Int { moves.count }
    var fullMoves: Int { Int((Double(halfMoves) / 2.0).rounded(.up)) }
    
    init(moves: [Move] = [], state: State = .play) {
        self.moves = moves
        self.state = state
    }
    
    mutating func update(with move: Move, state: State) {
        moves.append(move)
        self.state = state
        delegate?.notation(self, didAddMove: move, state: state)
    }
}
