//
//  Notation.swift
//  Chess
//
//  Created by Oleg Kovtun on 04.12.2025.
//

struct Notation {
    enum Move: Hashable, CustomStringConvertible {
        case unknown // used for FEN format
        case move(piece: Piece, to: Position, captured: Piece? = nil, promoted: Piece? = nil, similartPieces: [Piece] = [])
        case castle(king: Piece, rook: Piece, kingTo: Position, rookTo: Position, short: Bool)
        
        var description: String {
            switch self {
            case let .move(piece, position, captured, promoted, _):
                let capturedDescription = captured != nil ? "x" : ""
                let promotedDescription = promoted != nil ? "=\(promoted!.type.description)" : ""
                return "\(piece.description)\(capturedDescription)\(position.description)\(promotedDescription)"
            case let .castle(_, _, _, _, short):
                return "\(short ? "O-O" : "O-O-O")"
            default:
                return ""
            }
        }
    }
    
    enum State: Hashable, CustomStringConvertible, Codable {
        enum DrawReason: Hashable, CustomStringConvertible, Codable {
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
        
        case idle // default
        case play
        case check
        case mate(winner: Piece.Color)
        case draw(reason: DrawReason)
        
        var canStart: Bool {
            switch self {
            case .idle: return true
            default: return false
            }
        }
        
        var canMove: Bool {
            switch self {
            case .play, .check: return true
            default: return false
            }
        }
        
        var description: String {
            switch self {
            case .check: return "+"
            case .mate: return "#"
            default: return ""
            }
        }
        
        var result: String? {
            switch self {
            case let .mate(winner): return winner == .white ? "1-0" : "0-1"
            case .draw: return "1/2-1/2"
            default: return nil
            }
        }
    }
    
    private(set) var moves: [Move]
    private(set) var states: [State]
    private(set) var positionsCount: [String: Int]
    private(set) var positions: [String]
    private(set) var openingTrie: OpeningsTrie? = OpeningsTrie.shared
    private var defaultState = State.idle
    private var defaultLastActiveMoveIndex = 0
    private var defaultResult: [Int: String]? // in case we have draw by mutal agreement or someone resigns
    
    var halfMoves: Int { moves.count }
    var fullMoves: Int { Int((Double(halfMoves) / 2.0).rounded(.up)) }
    var state: State { states.last ?? defaultState }
    var move: Move { moves.last ?? .unknown }
    var openingTitle: String? { openingTrie?.title }
    var result: String? { state.result ?? defaultResult?[halfMoves] }
    
    var lastActiveMoveIndex: Int {
        {
            guard let index = moves.lastIndex(where: { move in
                switch move {
                case let .move(piece, _, captured, _, _): return piece.type == .pawn || captured != nil
                default: return false
                }
            }) else { return nil }
            return moves.count - index - 1
        }() ?? defaultLastActiveMoveIndex
    }
    
    init(moves: [Move] = [], states: [State] = [], positions: [String] = []) {
        self.moves = moves
        self.states = states
        self.positions = positions
        self.positionsCount = positions.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }
}

// MARK: Public interface
extension Notation {
    mutating func update(with move: Move? = nil, state: State, position: String, opening: OpeningsTrie?) {
        if let move { moves.append(move) }
        states.append(state)
        positions.append(position)
        positionsCount[position, default: 0] += 1
        openingTrie = opening ?? openingTrie
    }
    
    mutating func undo() -> Move? {
        guard !moves.isEmpty else { return nil }
        let move = moves.removeLast()
        states.removeLast()
        let position = positions.removeLast()
        positionsCount[position, default: 0] -= 1
        if (openingTrie?.movesCount ?? 0) < moves.count {
            openingTrie = openingTrie?.parent
        }
        return move
    }
    
    mutating func start(with result: [Int: String]? = nil) {
        defaultState = .play
        defaultResult = result
    }
    
    mutating func setHalfmoveClock(_ index: Int) {
        defaultLastActiveMoveIndex = index
    }
}
