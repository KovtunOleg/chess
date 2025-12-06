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
    private var board: [[Square]]
    private var notation: Notation
    private(set) var turn: Piece.Color
    private var copy: Game {
        let game = Game()
        game.board = board.copy
        game.notation = notation
        game.turn = turn
        return game
    }
    
    init() {
        board = [[Square]].empty
        turn = .white
        notation = Notation()
    }
    
    func reset(_ notationDelegate: NotationDelegate? = nil) {
        do {
            let (board, turn, notation) = try FENParser.parse(fen: FENParser.startPosition)
            self.board = board
            self.turn = turn
            self.notation = notation
        } catch {
            guard error is FENParser.ParsingError else { print("Unknown error"); return }
            print("Invalid FEN format")
        }
        notation.delegate = notationDelegate
    }
    
    @discardableResult
    func move(_ piece: Piece, to destination: Square, force: Bool = false) -> Bool {
        guard force || moves(for: piece).contains(destination.position) else { return false }
        var sourcePiece: Piece?
        var destinationPiece: Piece?
        if let source = piece.position {
            piece.movesCount += 1
            sourcePiece = piece.copy
            destinationPiece = square(at: destination.position).piece?.copy
            switch piece.type {
            case .pawn:
                guard destinationPiece == nil else { break }
                if destination.position.file != source.file {
                    // enPassant
                    square(at: Position(rank: source.rank, file: destination.position.file)).piece = nil
                } else if destination.position.rank == 0 || destination.position.rank == Game.size - 1 {
                    // promotion
                    
                }
            case .king:
                // castle
                guard destinationPiece == nil, destination.position.rank == source.rank, abs(source.file - destination.position.file) > 1 else { break }
                let rookPosition = Position(rank: source.rank, file: source.file > destination.position.file ? 0 : Game.size - 1)
                destinationPiece?.movesCount += 1
                destinationPiece = square(at: rookPosition).piece?.copy
                square(at: Position(rank: source.rank, file: source.file > destination.position.file ? source.file - 1 : source.file + 1)).piece = destinationPiece
                square(at: rookPosition).piece = nil
            default: break
            }
            square(at: source).piece = nil
        }
        square(at: destination.position).piece = piece
        if let sourcePiece {
            updateNotation(sourcePiece: sourcePiece, destinationPiece: destinationPiece, for: destination.position)
            turn.toggle()
        }
        return true
    }
    
    func square(at position: Position) -> Square {
        board[position.rank][position.file]
    }
    
    func moves(for piece: Piece, testCheck: Bool = true) -> [Position] {
        guard let position = piece.position, piece.color == turn else { return [] }
        var moves = [Position]()
        for direction in piece.directions {
            var count = 0
            var position = position
            while count < piece.limit {
                position = Position(rank: position.rank + direction[0], file: position.file + direction[1])
                guard isLegalMove(piece, to: position, testCheck: testCheck) else { break }
                moves.append(position)
                guard square(at: position).piece == nil else { break }
                count += 1
            }
        }
        switch piece.type {
        case .pawn:
            var pawnMoves = [Position]()
            // enPassant
            if case let .move(piece: pawn, to: pawnPosition) = notation.moves.last, let prevPawnPosition = pawn.position,
               pawn.type == .pawn, pawn.movesCount == 1, abs(prevPawnPosition.rank - pawnPosition.rank) == 2 {
                for file in [-1, 1] {
                    guard position.rank == pawnPosition.rank, (position.file - pawnPosition.file) == file else { continue }
                    let enPassantPosition = Position(rank: position.rank + (piece.color == .white ? 1 : -1), file: pawnPosition.file)
                    pawnMoves.append(enPassantPosition)
                }
            }
            // take
            for file in [-1, 1] {
                let takePosition = Position(rank: position.rank + (piece.color == .white ? 1 : -1), file: position.file + file)
                guard takePosition.isValid, let enemyPiece = square(at: takePosition).piece, enemyPiece.color != piece.color else { continue }
                pawnMoves.append(takePosition)
            }
            moves.append(contentsOf: pawnMoves.filter { isLegalMove(piece, to: $0, testCheck: testCheck) } )
        case .king:
            // castle
            guard !isCheck(color: piece.color) else { break }
            let rooks = board.pieces.filter({ $0.type == .rook && $0.color == piece.color })
            outer: for rook in rooks {
                guard rook.movesCount == 0, piece.movesCount == 0, let rookPosition = rook.position else { continue }
                let direction = rookPosition.file < position.file ? -1 : 1
                var position = position
                var count = 0
                while position != rookPosition, count < 2 {
                    position = Position(rank: position.rank, file: position.file + direction)
                    guard square(at: position).piece == nil, isLegalMove(piece, to: position, testCheck: testCheck) else { continue outer }
                    count += 1
                }
                moves.append(position)
            }
        default: break
        }
        return moves
    }
}

extension Game {
    private func isCheck(color: Piece.Color) -> Bool {
        let pieces = board.pieces
        let enemyPieces = pieces.filter { $0.color != color }
        guard let king = pieces.first(where: { $0.type == .king && $0.color == color }),
              let position = king.position else { return false }
        for enemyPiece in enemyPieces {
            var moves = moves(for: enemyPiece, testCheck: false)
            switch enemyPiece.type {
            case .pawn:
                moves.removeAll(where: { $0.file == position.file })
            default: break
            }
            guard !moves.contains(position) else { return true }
        }
        return false
    }
    
    private func isMate(isCheck: Bool, color: Piece.Color) -> Bool {
        guard isCheck else { return false }
        guard let king = board.pieces.first(where: { $0.type == .king && $0.color == color }) else { return false }
        return moves(for: king, testCheck: false).isEmpty
    }
    
    private func isStalemate(isCheck: Bool, color: Piece.Color) -> Bool {
        guard !isCheck else { return false }
        return !board.pieces.contains(where: { $0.color == color && !moves(for: $0, testCheck: false).isEmpty })
    }
    
    private func isLegalMove(_ piece: Piece, to position: Position, testCheck: Bool) -> Bool {
        guard position.isValid else { return false }
        if let otherPiece = square(at: position).piece,
           piece.color == otherPiece.color { return false }
        guard testCheck, let sourcePosition = piece.position else { return true }
        let copy = copy
        copy.move(copy.square(at: sourcePosition).piece!, to: copy.square(at: position), force: true)
        return !copy.isCheck(color: piece.color)
    }
    
    private func updateNotation(sourcePiece: Piece, destinationPiece: Piece?, for position: Position) {
        let opponentColor: Piece.Color = sourcePiece.color == .white ? .black : .white
        let move: Notation.Move = {
            if isCheck(color: opponentColor) {
                guard isMate(isCheck: true, color: opponentColor) else { return .check(piece: sourcePiece) }
                return .mate(piece: sourcePiece)
            } else {
                guard isStalemate(isCheck: false, color: opponentColor) else { return .stalemate(piece: sourcePiece) }
                if let destinationPiece {
                    guard sourcePiece.type == .king, destinationPiece.type == .rook, sourcePiece.color == destinationPiece.color,
                          let kingPosition = sourcePiece.position, let rookPosition = destinationPiece.position
                    else { return .capture(piece: sourcePiece, captured: destinationPiece) }
                    return .castle(king: sourcePiece, rook: destinationPiece, short: abs(kingPosition.file - rookPosition.file) == 3 )
                } else {
                    return .move(piece: sourcePiece, to: position)
                }
            }
        }()
        notation.append(move)
    }
}
