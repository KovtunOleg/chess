//
//  CPU.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import Foundation

final class CPU {
    /// returns position evaluation at the given `depth` and the best moves line
    func dfs(game: Game, depth: Int, alpha: Int = Int.min, beta: Int = Int.max, moves: [Notation.Move] = []) async -> (Int, [Notation.Move]) {
        await Task {
            switch game.notation.state {
            case .draw: return (0, moves)
            case let .mate(winner): return (winner == .white ? Int.max : Int.min, moves)
            default: guard depth > 0 else { return (evaluate(game: game), moves) }
            }
            var alpha = alpha, beta = beta
            let pieces = game.board.pieces
            var bestScore: Int, bestMoves = [Notation.Move]()
            switch game.turn {
            case .white:
                bestScore = Int.min
                for piece in pieces where piece.color == .white {
                    for position in await sortedMoves(game: game, piece: piece) {
                        guard let move = await game.move(piece, to: game.square(at: position), force: true) else { continue }
                        let (score, moves) = await dfs(game: game, depth: depth - 1, alpha: alpha, beta: beta, moves: moves + [move])
                        piece.position = game.undo()?.position
                        bestMoves = bestMoves.isEmpty ? moves : bestMoves
                        if score > bestScore {
                            bestScore = score
                            bestMoves = moves
                        }
                        alpha = max(alpha, bestScore)
                        if alpha >= beta {
                            break
                        }
                    }
                }
            case .black:
                bestScore = Int.max
                for piece in pieces where piece.color == .black {
                    for position in await sortedMoves(game: game, piece: piece) {
                        guard let move = await game.move(piece, to: game.square(at: position), force: true) else { continue }
                        let (score, moves) = await dfs(game: game, depth: depth - 1, alpha: alpha, beta: beta, moves: moves + [move])
                        piece.position = game.undo()?.position
                        bestMoves = bestMoves.isEmpty ? moves : bestMoves
                        if score < bestScore {
                            bestScore = score
                            bestMoves = moves
                        }
                        beta = min(beta, bestScore)
                        if alpha >= beta {
                            break
                        }
                    }
                }
            }
            return (bestScore, bestMoves)
        }.value
    }
}

extension CPU {
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
    
    private func sortedMoves(game: Game, piece: Piece) async -> [Position] {
        (await game.moves(for: piece)).sorted { lhs, rhs in
            let lhsCaptures = game.square(at: lhs).piece != nil
            let rhsCaptures = game.square(at: rhs).piece != nil
            guard lhsCaptures != rhsCaptures else {
                let lhsPiece = Piece(color: piece.color, type: piece.type, position: lhs)
                let rhsPiece = Piece(color: piece.color, type: piece.type, position: rhs)
                return lhsPiece.value > rhsPiece.value
            }
            return rhsCaptures && !rhsCaptures
        }
    }
}
