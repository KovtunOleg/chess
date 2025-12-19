//
//  ChessTests.swift
//  ChessTests
//
//  Created by Oleg Kovtun on 17.12.2025.
//

import Testing
import XCTest
@testable import Chess

enum ParsingError: LocalizedError, CustomStringConvertible {
    var description: String {
        switch self {
        case let .missingFile(fileName): return "Missing file: \(fileName).json"
        case let .wrongFormat(error): return "File has wrong format: \(error)"
        }
    }
    
    case missingFile(String)
    case wrongFormat(String)
}

struct TestPosition: Equatable, Codable {
    let fen: String
    let movesCount: Int
    let state: Notation.State
}

struct TestGame: Equatable, Codable {
    let pgn: String
    let name: String
    let opening: String
    let movesCount: Int
    let state: Notation.State
}

@MainActor
class ChessTests {
    private static let FENPositionsFileName = "test_fen_positions"
    private static let PGNGamesFileName = "test_pgn_games"
    
    @Test("Test game states for given FEN positions") func FENpositions() async throws {
        do {
            var game: Game
            for testPosition: TestPosition in try getJSONData(fileName: ChessTests.FENPositionsFileName) {
                game = try FENParser.parse(fen: testPosition.fen)
                await game.start()
                let movesCount = await getMovesCount(from: game)
                #expect(movesCount == testPosition.movesCount, "\(testPosition.fen)")
                #expect(game.notation.state == testPosition.state, "\(testPosition.fen)")
            }
        } catch {
            #expect(Bool(false), "\(error.localizedDescription)")
        }
    }
    
    @Test("Test threefold repetition") func threefoldRepetition() async throws {
        do {
            let game = try FENParser.parse(fen: FENParser.startPosition)
            await game.start()
            let b1Square = Position(rank: 0, file: 1)
            let a3Square = Position(rank: 2, file: 0)
            let b8Square = Position(rank: 7, file: 1)
            let a6Square = Position(rank: 5, file: 0)
            for _ in 0..<3 {
                for move in [(b1Square, a3Square), (b8Square, a6Square), (a3Square, b1Square), (a6Square, b8Square)] { // move knights aimlessly
                    await game.move(game.square(at: move.0).piece!, to: game.square(at: move.1))
                }
            }
            #expect(game.notation.state == .draw(reason: .threefoldRepetition), "\(FENParser.parse(game: game))")
        } catch {
            #expect(Bool(false), "\(error.localizedDescription)")
        }
    }
    
    @Test("Test PGN games") func PGNGames() async throws {
        do {
            for testGame: TestGame in try getJSONData(fileName: ChessTests.PGNGamesFileName) {
                let game = try await PGNParser.parse(pgn: testGame.pgn)
                #expect(game.notation.fullMoves == testGame.movesCount, "\(testGame.name)")
                #expect(game.notation.state == testGame.state, "\(testGame.name)")
                #expect(game.notation.openingTitle == testGame.opening, "\(testGame.name)")
                #expect(String(await PGNParser.parse(game: game).characters[...]) == testGame.pgn, "\(testGame.name)")
            }
        } catch {
            #expect(Bool(false), "\(error.localizedDescription)")
        }
    }
}

extension ChessTests {
    private func getJSONData<T: Codable>(fileName: String) throws -> [T] {
        guard let fileURL = Bundle(for: ChessTests.self).url(forResource: fileName, withExtension: "json") else {
            throw ParsingError.missingFile(fileName)
        }
        do {
            return try JSONDecoder().decode([T].self, from: try Data(contentsOf: fileURL))
        } catch {
            throw ParsingError.wrongFormat(error.localizedDescription)
        }
    }
    
    private func getMovesCount(from game: Game) async -> Int {
        let pieces = game.board.pieces.filter { $0.color == game.turn }
        var count = 0
        for piece in pieces {
            let moves = await game.moves(for: piece)
            count += moves.reduce(0) { $0 + (piece.type == .pawn && ($1.rank == 0 || $1.rank == Game.size - 1) ? 4 : 1) } // promotion gives 4 possible moves
        }
        return count
    }
}
