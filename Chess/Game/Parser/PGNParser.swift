//
//  PGNParser.swift
//  Chess
//
//  Created by Oleg Kovtun on 21.12.2025.
//

import Foundation
import SwiftUI

final class PGNParser {
    enum ParsingError: Error {
        case invalidPGNFormat(String)
    }
    
    static func parse(pgn: String) async throws -> Game {
        let data = parseMovesAndResult(pgn: pgn)
        let (moves, result) = (data.moves, data.result)
        let game = try FENParser.parse(fen: FENParser.startPosition)
        await game.start(with: result)
        for move in moves {
            guard await parseMove(game: game, move: move) != nil else { throw ParsingError.invalidPGNFormat(move) }
        }
        return game
    }
    
    static func parseMovesAndResult(pgn: String) -> (moves: [String], result: [Int: String]?) {
        let match = try? /(?<moves>.*?)(#? (?<result>(1\/2-1\/2|0-1|1-0)))?/.wholeMatch(in: pgn)
        let moves = match?.moves
            .split(separator: " ")
            .map { String((try? /(\d+\.)?(?<move>.*?)\+?/.wholeMatch(in: $0))?.move ?? "") }
            .filter { !$0.isEmpty } ?? []
        let result: [Int: String]? = {
            guard let result = match?.result else { return nil }
            return [moves.count: String(result)]
        }()
        return (moves, result)
    }
    
    static func parseMove(game: Game, move: String, force: Bool = false) async -> Notation.Move? {
        if let match = try? /(?<type>[QKRBN]?)(?<fromFile>[a-h]?)(?<fromRank>[1-8]?)x?(?<toFile>[a-h]{1})(?<toRank>[1-8]{1})(=(?<promoted>[QKRBN]{1}))?.*/.wholeMatch(in: move) {
            let type = Piece.pgnMap["\(match.type)"] ?? .pawn, promotedType = Piece.pgnMap["\(match.promoted ?? "Q")"] ?? .queen,
                toFile = (match.toFile.first ?? "a").fileInt, toRank = (match.toRank.first ?? "1").rankInt,
                fromFile = match.fromFile.first?.fileInt, fromRank = match.fromRank.first?.rankInt,
                position = Position(rank: toRank, file: toFile)
            guard let piece = await {
                for p in game.board.pieces where p.type == type && p.color == game.turn &&
                (fromRank == nil || fromRank == p.position?.rank) && (fromFile == nil || fromFile == p.position?.file) {
                    if (await game.moves(for: p)).contains(position) {
                        return p
                    }
                }
                return nil
            }(),
            let move = await game.move(piece,
                                       to: game.square(at: Position(rank: toRank, file: toFile)),
                                       onPromote: { _,_ in Task { Piece(color: game.turn, type: promotedType) } },
                                       force: force) else {
                return nil
            }
            return move
        } else if (try? /(O-O-O|O-O)/.wholeMatch(in: move)) != nil {
            let short = move.count == 3
            guard let king = game.board.pieces.first(where: { $0.type == .king &&  $0.color == game.turn }), let kingPosition = king.position,
                  let move = await game.move(king, to: game.square(at: Position(rank: kingPosition.rank, file: kingPosition.file + (short ? 2 : -2))), force: force) else {
                return nil
            }
            return move
        }
        return nil
    }
    
    static func parse(game: Game,
                      font: Font = .system(size: 14, weight: .regular),
                      lastMoveFont: Font = .system(size: 14, weight: .semibold),
                      shorten: Bool = true) async -> AttributedString {
        let moves = game.notation.moves
        let states = game.notation.states
        let result = game.notation.result
        var attributedString = AttributedString("")
        for (i, fullMove) in moves.chunked(into: 2).enumerated() {
            if fullMove.first != .unknown {
                for (j, move) in fullMove.enumerated() {
                    let index = i * 2 + j + 1
                    let isLastMove = index == moves.count
                    let moveDescription = parseMove(game: game, move: move, shorten: shorten)
                    var attributedMove = AttributedString((j == 0 ? "\(i + 1).\u{00a0}" : "") + moveDescription + states[min(index,states.count - 1)].description + (isLastMove ? "": " "))
                    attributedMove.font = isLastMove ? lastMoveFont : font
                    attributedString.append(attributedMove)
                }
            }
        }
        if let result {
            var attributedResult = AttributedString(" " + result)
            attributedResult.font = lastMoveFont
            attributedString.append(attributedResult)
        }
        return attributedString
    }
    
    static func parseMove(game: Game, move: Notation.Move, shorten: Bool = true) -> String {
        var moveDescription = move.description
        guard shorten else { return moveDescription }
        switch move {
        case let .move(piece, _, captured, _, similarPieces):
            var shortenRank = true, shortenFile = !(captured != nil && piece.type == .pawn)
            for similarPiece in similarPieces {
                if similarPiece.position?.file != piece.position?.file {
                    shortenFile = false
                } else if similarPiece.position?.rank != piece.position?.rank {
                    shortenRank = false
                }
                guard shortenRank || shortenFile else { break }
            }
            moveDescription.removeFirst(piece.description.count)
            return piece.description(shortenFile: shortenFile, shortenRank: shortenRank) + moveDescription
        default: break
        }
        return moveDescription
    }
}
