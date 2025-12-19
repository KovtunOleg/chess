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
        let moves = parseMoves(pgn: pgn)
        let game = try FENParser.parse(fen: FENParser.startPosition)
        await game.start()
        for move in moves {
            guard await parseMove(game: game, move: move) != nil else { throw ParsingError.invalidPGNFormat(move) }
        }
        return game
    }
    
    static func parseMoves(pgn: String) -> [String] {
        pgn
            .split(separator: "#")[0]
            .split(separator: " ")
            .map { String((try? /(\d+\.)?(?<move>.*?)\+?/.wholeMatch(in: $0))?.move ?? "") }
            .filter { !$0.isEmpty }
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
        var attributedString = AttributedString("")
        for (i, fullMove) in moves.chunked(into: 2).enumerated() {
            if fullMove.first != .unknown {
                for (j, move) in fullMove.enumerated() {
                    let index = i * 2 + j + 1
                    let isLastMove = index == moves.count
                    let moveDescription = await parseMove(game: game, move: move, shorten: shorten)
                    var attributedMove = AttributedString((j == 0 ? "\(i + 1).\u{00a0}" : "") + moveDescription + states[index].description + (isLastMove ? "": " "))
                    attributedMove.font = isLastMove ? lastMoveFont : font
                    attributedString.append(attributedMove)
                }
            }
        }
        return attributedString
    }
    
    static func parseMove(game: Game, move: Notation.Move, shorten: Bool = true) async -> String {
        var moveDescription = move.description
        guard shorten else { return moveDescription }
        switch move {
        case let .move(piece, position, captured, _):
            let similarPieces = game.board.pieces.filter { $0.color == piece.color && $0.type == piece.type && $0.position != piece.position }
            var shortenRank = true, shortenFile = !(captured != nil && piece.type == .pawn)
            for similarPiece in similarPieces where await game.moves(for: similarPiece).contains(position) {
                if similarPiece.position?.rank == piece.position?.rank { shortenRank = false }
                if similarPiece.position?.file == piece.position?.file { shortenFile = false }
                guard shortenRank || shortenFile else { break }
            }
            moveDescription.removeFirst(piece.description.count)
            return piece.description(shortenFile: shortenFile, shortenRank: shortenRank) + moveDescription
        default: break
        }
        return moveDescription
    }
}
