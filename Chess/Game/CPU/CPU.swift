//
//  CPU.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import Foundation

final class CPU {
    /// returns position evaluation at the given `depth` and the best moves line
    func search(game: Game, gameSettings: GameSettings) async -> (Int, [Notation.Move]) {
        let averageMovesCount = 40 // approximately
        let timePerMove = DispatchTimeInterval.milliseconds( Int((gameSettings.timeControl.time * Double(secondsInMinute) / Double(averageMovesCount))) * millisecondsInSecond )
        return await dfs(game: game, depth: gameSettings.level.depth, until: DispatchTime.now().advanced(by: timePerMove))
    }
}

extension CPU {
    private func dfs(game: Game,
                     depth: Int,
                     until: DispatchTime,
                     alpha: Int = Int.min,
                     beta: Int = Int.max,
                     moves: [Notation.Move] = []) async -> (Int, [Notation.Move]) {
        await Task(priority: .high) {
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
                    let (score, moves) = await dfs(game: game, depth: depth - 1, until: until, alpha: alpha, beta: beta, moves: moves + [move])
                    piece.position = game.undo()?.position
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
                    let (score, moves) = await dfs(game: game, depth: depth - 1, until: until, alpha: alpha, beta: beta, moves: moves + [move])
                    piece.position = game.undo()?.position
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
}
