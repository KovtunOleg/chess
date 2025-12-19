//
//  CPU.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import Foundation

final class CPU {
    typealias Line = (Int, [Notation.Move])
    private var task: Task<(Int, [Notation.Move])?, Never>?
    
    /// returns position evaluation at the given `depth` and the best moves line
    func search(game: Game, gameSettings: GameSettings) async -> Line? {
        task = Task(priority: .high) {
            let line = await useOpeningsBook(game: game.copy)
            guard line == nil else { return line }
            let averageMovesCount = 40 // approximately
            let timePerMove = DispatchTimeInterval.milliseconds( Int((gameSettings.timeControl.time * Double(secondsInMinute) / Double(averageMovesCount))) * millisecondsInSecond )
            let until = DispatchTime.now().advanced(by: timePerMove)
            var best: Line?
            for depth in GameSettings.GameLevel.easy.depth...gameSettings.level.depth {
                let current = await dfs(game: game.copy, depth: depth, until: depth > GameSettings.GameLevel.easy.depth ? until : .distantFuture)
                guard let current else { break }
                guard until > DispatchTime.now() else {
                    best = best == nil ? current : best
                    break
                }
                best = current
            }
            guard let task, !task.isCancelled else { return nil }
            return best
        }
        return await task?.value
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

extension CPU {
    private func dfs(game: Game,
                     depth: Int,
                     until: DispatchTime,
                     alpha: Int = Int.min,
                     beta: Int = Int.max,
                     moves: [Notation.Move] = []) async -> Line? {
        await Task {
            guard let task, !task.isCancelled else { return nil }
            switch game.notation.state {
            case .draw: return (0, moves)
            case let .mate(winner): return (winner == .white ? Int.max : Int.min, moves)
            default: guard depth > 0, until > DispatchTime.now() else { return (evaluate(game: game), moves) }
            }
            var alpha = alpha, beta = beta
            var bestScore: Int, bestMoves = [Notation.Move]()
            switch game.turn {
            case .white:
                bestScore = Int.min
                for (piece, position) in await sortedMoves(game: game) {
                    guard let move = await game.move(piece, to: game.square(at: position), force: true) else { continue }
                    guard let (score, moves) = await dfs(game: game, depth: depth - 1, until: until, alpha: alpha, beta: beta, moves: moves + [move]) else { return nil }
                    game.undo(for: piece)
                    bestMoves = bestMoves.isEmpty ? moves : bestMoves
                    if score > bestScore {
                        bestScore = score
                        bestMoves = moves
                    }
                    alpha = max(alpha, score)
                    if beta <= alpha {
                        break
                    }
                }
            case .black:
                bestScore = Int.max
                for (piece, position) in await sortedMoves(game: game) {
                    guard let move = await game.move(piece, to: game.square(at: position), force: true) else { continue }
                    guard let (score, moves) = await dfs(game: game, depth: depth - 1, until: until, alpha: alpha, beta: beta, moves: moves + [move]) else { return nil }
                    game.undo(for: piece)
                    bestMoves = bestMoves.isEmpty ? moves : bestMoves
                    if score < bestScore {
                        bestScore = score
                        bestMoves = moves
                    }
                    beta = min(beta, score)
                    if beta <= alpha {
                        break
                    }
                }
            }
            return (bestScore, bestMoves)
        }.value
    }
    
    private func evaluate(game: Game) -> Int {
        var whiteScore = 0, blackScore = 0
        for piece in game.board.pieces {
            switch piece.color {
            case .white: whiteScore += piece.value
            case .black: blackScore += piece.value
            }
        }
        return whiteScore - blackScore
    }

    private func sortedMoves(game: Game) async -> [(Piece, Position)] {
        var moves = [(Piece, Position)]()
        for piece in game.board.pieces.filter({ $0.color == game.turn }) {
            moves.append(contentsOf: (await game.moves(for: piece)).map { (piece, $0) })
        }
        return moves.sorted { lhs, rhs in
            let lhsPiece = lhs.0, rhsPiece = rhs.0
            let lhsPosition = lhs.1, rhsPosition = rhs.1
            let lhsPromotes = lhsPiece.type == .pawn && (lhsPosition.rank == Game.size - 1 || lhsPosition.rank == 0)
            let rhsPromotes = rhsPiece.type == .pawn && (rhsPosition.rank == Game.size - 1 || rhsPosition.rank == 0)
            guard lhsPromotes == rhsPromotes else { return lhsPromotes && !rhsPromotes }
            let lhsCaptures = game.square(at: lhsPosition).piece != nil
            let rhsCaptures = game.square(at: rhsPosition).piece != nil
            guard lhsCaptures == rhsCaptures else { return lhsCaptures && !rhsCaptures }
            let lhsValue = Piece(color: lhsPiece.color, type: lhsPiece.type, position: lhsPosition).value
            let rhsValue = Piece(color: rhsPiece.color, type: rhsPiece.type, position: rhsPosition).value
            return lhsValue - lhsPiece.value > rhsValue - rhsPiece.value
        }
    }
    
    private func useOpeningsBook(game: Game) async -> Line? {
        guard let children = game.notation.openingTrie?.children,
              let opening = children.randomElement(),
              let move = await PGNParser.parseMove(game: game, move: opening.key, force: true) else {
            return nil
        }
        return (0, [move])
    }
}
