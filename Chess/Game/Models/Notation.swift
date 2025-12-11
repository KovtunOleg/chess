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
            case let .castle(_, _, short):
                return "\(short ? "O-O" : "O-O-O")"
            default:
                return ""
            }
        }
    }
    
    enum State: Hashable, CustomStringConvertible {
        enum DrawReason: Hashable, CustomStringConvertible {
            case stalemate
            case threefoldRepetition
            case insufficientMaterial
            case fiftyMoveRule
            
            var description: String {
                switch self {
                case .stalemate: "Stalemate"
                case .threefoldRepetition: "Threefold repetition"
                case .fiftyMoveRule: "Fifty move rule"
                case .insufficientMaterial: "Insufficient material"
                }
            }
        }
        
        case play
        case check
        case mate(winner: Piece.Color)
        case draw(reason: DrawReason)
        
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
    private(set) var states: [State]
    private(set) var positions: [String: Int]
    
    var delegate: NotationDelegate?
    
    var halfMoves: Int { moves.count }
    var fullMoves: Int { Int((Double(halfMoves) / 2.0).rounded(.up)) }
    var state: State { states.last ?? .play }
    var lastActiveMoveIndex: Int {
        let index = moves.lastIndex { move in
            switch move {
            case let .move(piece, _, captured, _):
                return piece.type == .pawn || captured != nil
            case .castle: return false
            case .unknown: return true
            }
        } ?? 0
        return Int((Double(index) / 2.0).rounded(.up))
    }
    
    init(moves: [Move] = [], states: [State] = [], positions: [String: Int] = [:]) {
        self.moves = moves
        self.states = states
        self.positions = positions
    }
    
    mutating func update(with move: Move, state: State, position: String) {
        moves.append(move)
        states.append(state)
        positions[position, default: 0] += 1
        delegate?.notation(self, didAddMove: move, state: state)
    }
}
