//
//  Game.swift
//  Chess
//
//  Created by Oleg Kovtun on 01.12.2025.
//

import SwiftUI
import Observation

@Observable
final class Game {
    static let size = 8
    private(set) var board: [[Square]]
    private(set) var notation: Notation
    
    var turn: Piece.Color {
        notation.halfMoves % 2 == 0 ? .white : .black
    }
    private var copy: Game {
        let game = Game()
        game.board = board.copy
        game.notation = notation
        game.notation.delegate = nil
        
        return game
    }
    
    var onPromote: ((Piece, Position) -> Task<Piece, Never>)? // default to queen
    
    init(board: [[Square]] = [[Square]].empty, notation: Notation = Notation()) {
        self.board = board
        self.notation = notation
    }
    
    @discardableResult
    func move(_ piece: Piece, to destination: Square, force: Bool = false) async -> Bool {
        if !force {
            let moves = await moves(for: piece)
            guard moves.contains(destination.position) else { return false }
        }
        var sourcePiece: Piece
        var destinationPiece: Piece?
        var promotionPiece: Piece?
        var move = Notation.Move.unknown
        if let source = piece.position {
            piece.movesCount += 1
            sourcePiece = piece.copy
            destinationPiece = square(at: destination.position).piece?.copy
            move = .move(piece: sourcePiece, to: destination.position, captured: destinationPiece)
            switch piece.type {
            case .pawn:
                if destinationPiece == nil, destination.position.file != source.file {
                    // enPassant
                    let enPassantEnemyPosition = Position(rank: source.rank, file: destination.position.file)
                    move = .move(piece: sourcePiece, to: destination.position, captured: square(at: enPassantEnemyPosition).piece?.copy)
                    square(at: enPassantEnemyPosition).piece = nil
                } else if destination.position.rank == 0 || destination.position.rank == Game.size - 1 {
                    // promotion
                    promotionPiece = await onPromote?(piece, destination.position).value ?? Piece(color: piece.color, type: .queen, movesCount: piece.movesCount)
                    promotionPiece?.movesCount = piece.movesCount
                    move = .move(piece: sourcePiece, to: destination.position, captured: destinationPiece, promoted: promotionPiece)
                }
            case .king:
                // castle
                guard destinationPiece == nil, destination.position.rank == source.rank, abs(source.file - destination.position.file) > 1 else { break }
                let rookPosition = Position(rank: source.rank, file: source.file > destination.position.file ? 0 : Game.size - 1)
                destinationPiece?.movesCount = piece.movesCount
                destinationPiece = square(at: rookPosition).piece?.copy
                square(at: Position(rank: source.rank, file: source.file > destination.position.file ? source.file - 1 : source.file + 1)).piece = destinationPiece
                square(at: rookPosition).piece = nil
                move = .castle(king: sourcePiece, rook: destinationPiece!, short: abs(source.file - rookPosition.file) == 3)
            default:
                break
            }
            square(at: source).piece = nil
        }
        square(at: destination.position).piece = promotionPiece ?? piece
        if !force {
            await updateNotation(with: move)
        }
        return true
    }
    
    func square(at position: Position) -> Square {
        board[position.rank][position.file]
    }
    
    func moves(for piece: Piece, testCheck: Bool = true) async -> [Position] {
        guard let position = piece.position, notation.state == .play || notation.state == .check else { return [] }
        var moves = [Position]()
        for direction in piece.directions {
            var count = 0
            var position = position
            while count < piece.limit {
                position = Position(rank: position.rank + direction[0], file: position.file + direction[1])
                guard position.isValid else { break }
                if let otherPiece = square(at: position).piece,
                   (piece.type != .pawn && piece.color == otherPiece.color) ||
                    (piece.type == .pawn && piece.position?.file == otherPiece.position?.file) { break }
                moves.append(position)
                guard square(at: position).piece == nil else { break }
                count += 1
            }
        }
        switch piece.type {
        case .pawn:
            // enPassant
            if case let .move(piece: pawn, to: pawnPosition, _, _) = notation.moves.last, let prevPawnPosition = pawn.position,
               pawn.type == .pawn, pawn.movesCount == 1, abs(prevPawnPosition.rank - pawnPosition.rank) == 2 {
                for file in [-1, 1] {
                    guard position.rank == pawnPosition.rank, (position.file - pawnPosition.file) == file else { continue }
                    let enPassantPosition = Position(rank: position.rank + (piece.color == .white ? 1 : -1), file: pawnPosition.file)
                    moves.append(enPassantPosition)
                }
            }
            // take
            for file in [-1, 1] {
                let takePosition = Position(rank: position.rank + (piece.color == .white ? 1 : -1), file: position.file + file)
                guard takePosition.isValid, let enemyPiece = square(at: takePosition).piece, enemyPiece.color != piece.color else { continue }
                moves.append(takePosition)
            }
        case .king:
            // castle
            if testCheck {
                guard !(await isCheck(color: piece.color)) else { break }
            }
            let rooks = board.pieces.filter({ $0.type == .rook && $0.color == piece.color })
            outer: for rook in rooks {
                guard rook.movesCount == 0, piece.movesCount == 0, let rookPosition = rook.position else { continue }
                let direction = rookPosition.file < position.file ? -1 : 1
                var position = position
                var count = 0
                while position != rookPosition, count < 2 {
                    position = Position(rank: position.rank, file: position.file + direction)
                    guard square(at: position).piece == nil, await isLegalMove(piece, to: position, testCheck: testCheck) else { continue outer }
                    count += 1
                }
                moves.append(position)
            }
        default: break
        }
        var legalMoves = [Position]()
        for move in moves where await isLegalMove(piece, to: move, testCheck: testCheck)  {
            legalMoves.append(move)
        }
        return legalMoves
    }
}

extension Game {
    private func isCheck(color: Piece.Color) async -> Bool {
        let pieces = board.pieces
        let enemyPieces = pieces.filter { $0.color != color }
        guard let king = pieces.first(where: { $0.type == .king && $0.color == color }),
              let position = king.position else { return false }
        for enemyPiece in enemyPieces {
            let moves = await moves(for: enemyPiece, testCheck: false)
            guard !moves.contains(position) else { return true }
        }
        return false
    }
    
    private func isMate(isCheck: Bool, hasMoves: Bool) -> Bool {
        isCheck && !hasMoves
    }
    
    private func isDraw(isCheck: Bool, hasMoves: Bool, position: String, color: Piece.Color) -> Notation.State.DrawReason? {
        guard !isCheck else { return nil }
        let pieces = board.pieces
        func isSufficientMaterial(_ pieces: [Piece]) -> Bool {
            let set = pieces.map { $0.type == .bishop ? "\($0.position?.isLight == true ? "l" : "d")" : $0.description } // include case for same color bishops
            guard set.count < 3 else { return true }
            return !pieces.contains(where: { $0.type == .bishop || $0.type == .knight })
        }
        guard hasMoves else { return .stalemate }
        guard notation.positions[position, default: 0] < 2 else { return .threefoldRepetition }
        guard isSufficientMaterial(pieces.filter { $0.color == color }) ||
                isSufficientMaterial(pieces.filter { $0.color != color }) else { return .insufficientMaterial }
        guard notation.fullMoves - notation.lastActiveMoveIndex < 50 else { return .fiftyMoveRule }
        return nil
    }
    
    private func hasMoves(color: Piece.Color) async -> Bool {
        let currentPieces = board.pieces.filter { $0.color == color }
        return await {
            for piece in currentPieces where !(await moves(for: piece, testCheck: true).isEmpty) {
                return true
            }
            return false
        }()
    }
    
    private func isLegalMove(_ piece: Piece, to position: Position, testCheck: Bool) async -> Bool {
        guard testCheck, let sourcePosition = piece.position else { return true }
        let copy = copy
        await copy.move(copy.square(at: sourcePosition).piece!, to: copy.square(at: position), force: true)
        return !(await copy.isCheck(color: piece.color))
    }
    
    private func updateNotation(with move: Notation.Move) async {
        let opponentColor: Piece.Color = turn == .white ? .black : .white
        let position = String(FENParser.parse(game: self).split(separator: " ")[0])
        let state: Notation.State = await {
            let hasMoves = await hasMoves(color: opponentColor)
            guard !(await isCheck(color: opponentColor)) else { return isMate(isCheck: true, hasMoves: hasMoves) ? .mate(winner: turn) : .check }
            guard let drawReason = isDraw(isCheck: false, hasMoves: hasMoves, position: position, color: opponentColor) else { return .play }
            return .draw(reason: drawReason)
        }()
        notation.update(with: move, state: state, position: position)
    }
}
