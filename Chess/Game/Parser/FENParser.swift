//
//  FENParser.swift
//  Chess
//
//  Created by Oleg Kovtun on 06.12.2025.
//


final class FENParser {
    enum ParsingError: Error {
        case invalidFENFormat
    }
    static let startPosition = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    
    static func parse(fen: String, delegate: NotationDelegate? = nil) throws -> Game {
        let fenParts = fen.split(separator: " ")
        guard fenParts.count == 6 else { throw ParsingError.invalidFENFormat }
        
        // 1. Piece Placement
        let board = [[Square]].empty
        let rows = fenParts[0]
        for (rank, row) in rows.split(separator: "/").reversed().enumerated() {
            var file = 0
            for char in row {
                board[rank][file].piece = parsePiece(char)
                file += (Int("\(char)") ?? 1) // skip empty squares
            }
        }
        
        // 2. Active Color
        let turn: Piece.Color = fenParts[1] == "b" ? .black : .white
        
        // 3. Castling Rights
        let castlingRights = fenParts[2]
        let pieces = board.pieces
        func setCastlingRights(kingChar: Character, queenChar: Character, pieces: [Piece]) {
            let canCastleKingside = castlingRights.contains(kingChar)
            let canCastleQueenside = castlingRights.contains(queenChar)
            if !canCastleKingside { kingsideRook(pieces)?.movesCount = 1 }
            if !canCastleQueenside { queensideRook(pieces)?.movesCount = 1  }
            if !canCastleKingside || !canCastleQueenside { king(pieces)?.movesCount = 1 }
        }
        setCastlingRights(kingChar: "K", queenChar: "Q", pieces: pieces.filter { $0.color == .white })
        setCastlingRights(kingChar: "k", queenChar: "q", pieces: pieces.filter { $0.color == .black })
        
        // 4. Possible En Passant Targets
        let enPassant = fenParts[3]
        var enPassantMoves = [Notation.Move]()
        if enPassant != "-" {
            let pawnPosition = Position(
                rank: Int("\(enPassant.last ?? "0")") ?? 0 == 3 ? 4 : 5,
                file: Int(UnicodeScalar("\(enPassant.first ?? "a")")!.value - UnicodeScalar("a").value))
            if let pawn = pieces.first(where: { $0.type == .pawn && $0.position == pawnPosition }) {
                pawn.movesCount = 1
                let copy = pawn.copy
                copy.position = Position(rank: pawnPosition.rank + (pawn.color == .black ? 2 : -2), file: pawnPosition.file)
                enPassantMoves.append(.move(piece: copy, to: pawnPosition))
            }
        }
        
        // 5. Halfmove Clock
        let halfmoves = Int(fenParts[4]) ?? 0
        let moves = [Notation.Move](repeating: .unknown, count: halfmoves - enPassantMoves.count)
        var notation = Notation(moves: moves + enPassantMoves)
        notation.delegate = delegate
        
        // 6. Fullmove Number (not used)
        _ = Int(fenParts[5]) ?? 0
        
        return Game(board: board, notation: notation, turn: turn)
    }
    
    static func parse(game: Game) -> String {
        var parts = [String](repeating: "", count: 6)
        
        // 1. Piece Placement
        var positions = [String]()
        for row in game.board.reversed() {
            var current = ""
            var offset = 0
            for square in row {
                if let piece = square.piece {
                    current += offset > 0 ? "\(offset)" : ""
                    current += parseChar(piece)
                    offset = 0
                } else {
                    offset += 1
                }
            }
            positions.append(current + (offset > 0 ? "\(offset)" : ""))
        }
        parts[0] += positions.joined(separator: "/")
        
        // 2. Active Color
        parts[1] = game.turn == .white ? "w" : "b"
        
        // 3. Castling Rights
        let pieces = game.board.pieces
        func setCastlingRights(kingChar: Character, queenChar: Character, pieces: [Piece]) {
            if let king = king(pieces), king.movesCount == 0 {
                if let rook = kingsideRook(pieces), rook.movesCount == 0 { parts[2] += "\(kingChar)" }
                if let rook = queensideRook(pieces), rook.movesCount == 0 { parts[2] += "\(queenChar)" }
            }
        }
        setCastlingRights(kingChar: "K", queenChar: "Q", pieces: pieces.filter { $0.color == .white })
        setCastlingRights(kingChar: "k", queenChar: "q", pieces: pieces.filter { $0.color == .black })
        parts[2] = parts[2].isEmpty ? "-" : parts[2]
        
        // 4. Possible En Passant Targets
        parts[3] = "-"
        let moves = game.notation.moves
        if case let .move(piece: pawn, to: pawnPosition, _, _) = moves.last, let prevPawnPosition = pawn.position,
           pawn.type == .pawn, pawn.movesCount == 1, abs(prevPawnPosition.rank - pawnPosition.rank) == 2 {
            parts[3] = "\(pawnPosition.file.fileString)\((pawnPosition.rank == 3 ? 2 : 5).rankString)"
        }
        
        // 5. Halfmove Clock
        parts[4] = game.notation.halfMoves.description
        
        // 6. Fullmove Number
        parts[5] = game.notation.fullMoves.description
        
        return parts.joined(separator: " ")
    }
}

extension FENParser {
    private static func parsePiece(_ char: Character) -> Piece? {
        switch char {
        case "r", "R": return Piece(color: char == "r" ? .black : .white, type: .rook)
        case "n", "N": return Piece(color: char == "n" ? .black : .white, type: .knight)
        case "b", "B": return Piece(color: char == "b" ? .black : .white, type: .bishop)
        case "q", "Q": return Piece(color: char == "q" ? .black : .white, type: .queen)
        case "k", "K": return Piece(color: char == "k" ? .black : .white, type: .king)
        case "p", "P": return Piece(color: char == "p" ? .black : .white, type: .pawn)
        default: return nil
        }
    }
    
    private static func parseChar(_ piece: Piece) -> String {
        switch piece.type {
        case .pawn: return piece.color == .black ? "p" : "P"
        default: return piece.color == .black ? piece.type.description.lowercased() : piece.type.description
        }
    }
    
    private static func kingsideRook(_ pieces: [Piece]) -> Piece? {
        pieces.filter({ $0.type == .rook && $0.position?.file == Game.size - 1 }).first
    }
    
    private static func queensideRook(_ pieces: [Piece]) -> Piece? {
        pieces.filter({ $0.type == .rook && $0.position?.file == 0 }).first
    }
    
    private static func king(_ pieces: [Piece]) -> Piece? {
        pieces.filter({ $0.type == .king }).first
    }
}
