//
//  Game.swift
//  Chess
//
//  Created by Oleg Kovtun on 01.12.2025.
//

import Combine
import Observation
import SwiftUI

protocol GameProtocol {
    func move(_ piece: Piece, to destination: Square, force: Bool, needToUpdateNotation: Bool) async -> Notation.Move?
    func undo(for resetPiece: Piece?)
    func start() async
    func square(at position: Position) -> Square
    func moves(for piece: Piece) async -> [Position]
}

@Observable
final class Game: Equatable, Identifiable {
    static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.id == rhs.id
    }
    
    static let size = 8
    static let squaresCount = Game.size * Game.size
    private(set) var board: [[Square]]
    private(set) var notation: Notation
    private(set) var notationPublisher = PassthroughSubject<Notation, Never>()
    
    var copy: Game {
        Game(board: board.copy, notation: notation)
    }
    
    var turn: Piece.Color { notation.halfMoves % 2 == 0 ? .white : .black }
    var onPromote: ((Piece, Position) -> Task<Piece, Never>)? // default to queen
    
    init(board: [[Square]] = [[Square]].empty, notation: Notation = Notation()) {
        self.board = board
        self.notation = notation
    }
}

extension Game: GameProtocol {
    @discardableResult
    func move(_ piece: Piece, to destination: Square, force: Bool = false, needToUpdateNotation: Bool = true) async -> Notation.Move? {
        if !force {
            let moves = await moves(for: piece)
            guard moves.contains(destination.position) else { return nil }
        }
        var sourcePiece: Piece
        var destinationPiece: Piece?
        var promotionPiece: Piece?
        var move = Notation.Move.unknown
        if let source = piece.position {
            sourcePiece = piece.copy
            piece.movesCount += 1
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
                destinationPiece = square(at: rookPosition).piece?.copy
                let newRookPosition = Position(rank: source.rank, file: source.file > destination.position.file ? source.file - 1 : source.file + 1)
                move = .castle(king: sourcePiece, rook: destinationPiece!, kingTo: destination.position, rookTo: newRookPosition, short: abs(source.file - rookPosition.file) == 3)
                destinationPiece?.movesCount = piece.movesCount
                square(at: newRookPosition).piece = destinationPiece?.copy
                square(at: rookPosition).piece = nil
            default:
                break
            }
            square(at: source).piece = nil
        }
        square(at: destination.position).piece = promotionPiece ?? piece
        if needToUpdateNotation {
            await updateNotation(with: move)
        }
        return move
    }
    
    func undo(for resetPiece: Piece? = nil) {
        switch notation.undo() {
        case let .move(piece, position, captured, promoted):
            guard let piecePosition = piece.position else { break }
            let originalPiece = resetPiece ?? square(at: position).piece
            square(at: position).piece = nil
            square(at: piecePosition).piece = originalPiece
            originalPiece?.movesCount -= 1
            if let promotedPosition = promoted?.position {
                square(at: promotedPosition).piece = nil
            }
            if let capturedPosition = captured?.position {
                square(at: capturedPosition).piece = captured
            }
        case let .castle(king, rook, toKingPosition, toRookPosition, _):
            guard let kingPosition = king.position, let rookPosition = rook.position else { break }
            let originalKing = resetPiece ?? square(at: toKingPosition).piece
            let originalRook = square(at: toRookPosition).piece
            originalKing?.movesCount = 0
            originalRook?.movesCount = 0
            square(at: toKingPosition).piece = nil
            square(at: toRookPosition).piece = nil
            square(at: kingPosition).piece = originalKing
            square(at: rookPosition).piece = originalRook
        default:
            break
        }
        notationPublisher.send(notation)
    }
    
    func start() async {
        notation.start()
        await updateNotation()
    }
    
    func square(at position: Position) -> Square {
        board[position.rank][position.file]
    }
    
    func moves(for piece: Piece) async -> [Position] {
        guard let position = piece.position, notation.state.canMove else { return [] }
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
            if case let .move(pawn, pawnPosition, _, _) = notation.moves.last, let prevPawnPosition = pawn.position,
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
            guard notation.state != .check else { break }
            let rooks = board.pieces.filter({ $0.type == .rook && $0.color == piece.color })
            outer: for rook in rooks {
                guard rook.movesCount == 0, piece.movesCount == 0, let rookPosition = rook.position else { continue }
                let direction = rookPosition.file < position.file ? -1 : 1
                var position = position
                var count = 0
                while position != rookPosition, count < 2 {
                    position = Position(rank: position.rank, file: position.file + direction)
                    guard position.isValid, square(at: position).piece == nil, await isLegalMove(piece, to: position) else { continue outer }
                    count += 1
                }
                moves.append(position)
            }
        default: break
        }
        var legalMoves = [Position]()
        for move in moves where await isLegalMove(piece, to: move) {
            legalMoves.append(move)
        }
        return legalMoves
    }
}

extension Game {
    private func isCheck(color: Piece.Color) -> Bool {
        guard let king = board.pieces.first(where: { $0.type == .king && $0.color == color }),
              let position = king.position else { return false }
        let opponentColor: Piece.Color = color == .white ? .black : .white
        func isCheck(type: Piece.`Type`, condition: (Piece, Int) -> Bool) -> Bool {
            let piece = Piece(color: opponentColor, type: type)
            let directions = type == .pawn ? (color == .white ? [[1,-1],[1,1]] : [[-1,-1],[-1,1]]) : piece.directions
            let limit = type == .pawn ? 1 : piece.limit
            for direction in directions {
                var count = 0
                var position = position
                while count < limit {
                    position = Position(rank: position.rank + direction[0], file: position.file + direction[1])
                    guard position.isValid else { break }
                    if let otherPiece = square(at: position).piece {
                        guard otherPiece.color == opponentColor,
                              condition(otherPiece, count) else { break }
                        return true
                    }
                    count += 1
                }
            }
            return false
        }
        guard !isCheck(type: .rook, condition: { otherPiece, distance in
            otherPiece.type == .queen || otherPiece.type == .rook || (otherPiece.type == .king && distance == 0)
        }) else { return true }
        guard !isCheck(type: .bishop, condition: { otherPiece, distance in
            otherPiece.type == .queen || otherPiece.type == .bishop || (otherPiece.type == .king && distance == 0)
        }) else { return true }
        guard !isCheck(type: .knight, condition: { otherPiece, _ in
            otherPiece.type == .knight
        }) else { return true }
        guard !isCheck(type: .pawn, condition: { otherPiece, _ in
            otherPiece.type == .pawn
        }) else { return true }
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
            return set.count == 1 ? false : !pieces.contains(where: { $0.type == .bishop || $0.type == .knight })
        }
        guard hasMoves else { return .stalemate }
        guard notation.positionsCount[position, default: 0] < 3 else { return .threefoldRepetition }
        guard isSufficientMaterial(pieces.filter { $0.color == color }) ||
                isSufficientMaterial(pieces.filter { $0.color != color }) else { return .insufficientMaterial }
        guard notation.fullMoves - notation.lastActiveMoveIndex < 50 else { return .fiftyMoveRule }
        return nil
    }
    
    private func hasMoves(color: Piece.Color) async -> Bool {
        let currentPieces = board.pieces.filter { $0.color == color }
        for piece in currentPieces where !(await moves(for: piece).isEmpty) {
            return true
        }
        return false
    }
    
    private func isLegalMove(_ piece: Piece, to position: Position) async -> Bool {
        guard let sourcePosition = piece.position else { return true }
        let copy = copy
        await copy.move(copy.square(at: sourcePosition).piece!, to: copy.square(at: position), force: true, needToUpdateNotation: false)
        return !copy.isCheck(color: piece.color)
    }
    
    private func updateNotation(with move: Notation.Move? = nil) async {
        let opponentColor: Piece.Color = {
            guard move == nil else { return turn == .white ? .black : .white }
            return turn
        }()
        let winnerColor: Piece.Color = {
            guard move == nil else { return turn }
            return turn == .white ? .black : .white
        }()
        let position = String(FENParser.parse(game: self).split(separator: " ")[0])
        let state: Notation.State = await {
            let hasMoves = await hasMoves(color: opponentColor)
            guard !isCheck(color: opponentColor) else { return isMate(isCheck: true, hasMoves: hasMoves) ? .mate(winner: winnerColor) : .check }
            guard let drawReason = isDraw(isCheck: false, hasMoves: hasMoves, position: position, color: opponentColor) else { return .play }
            return .draw(reason: drawReason)
        }()
        notation.update(with: move, state: state, position: position)
        notationPublisher.send(notation)
    }
}
