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
    
    static func parse(fen: String) throws -> (board: [[Square]], turn: Piece.Color, Notation: Notation) {
        let fenParts = fen.split(separator: " ")
        guard fenParts.count == 6 else { throw ParsingError.invalidFENFormat }
        
        // 1. Piece Placement
        let board = [[Square]].empty
        let rows = fenParts[0]
        for (rank, row) in rows.split(separator: "/").reversed().enumerated() {
            var file = 0
            var piece: Piece?
            while file < Game.size {
                let char = row[row.index(row.startIndex, offsetBy: file)]
                switch char {
                case "r", "R": piece = Piece(color: char == "r" ? .black : .white, type: .rook)
                case "n", "N": piece = Piece(color: char == "n" ? .black : .white, type: .knight)
                case "b", "B": piece = Piece(color: char == "b" ? .black : .white, type: .bishop)
                case "q", "Q": piece = Piece(color: char == "q" ? .black : .white, type: .queen)
                case "k", "K": piece = Piece(color: char == "k" ? .black : .white, type: .king)
                case "p", "P": piece = Piece(color: char == "p" ? .black : .white, type: .pawn)
                default:
                    file += (Int("\(char)") ?? 1) // skip empty squares
                    continue
                }
                board[rank][file].piece = piece
                file += 1
            }
        }
        
        // 2. Active Color
        let turn: Piece.Color = fenParts[1] == "b" ? .black : .white
        
        // 3. Castling Rights
        let castlingRights = fenParts[2]
        let pieces = board.pieces
        let blackPieces = pieces.filter { $0.color == .black }
        let whitePieces = pieces.filter { $0.color == .white }
        if !castlingRights.contains("kq") {
            if !castlingRights.contains("k") {
                blackPieces.filter({ $0.type == .rook && $0.position?.file == Game.size - 1 }).first?.movesCount = 1
            }
            if !castlingRights.contains("q") {
                blackPieces.filter({ $0.type == .rook && $0.position?.file == 0 }).first?.movesCount = 1
            }
            blackPieces.filter({ $0.type == .king }).first?.movesCount += 1
        }
        if !castlingRights.contains("KQ") {
            if !castlingRights.contains("K") {
                whitePieces.filter({ $0.type == .rook && $0.position?.file == 0 }).first?.movesCount = 1
            }
            if !castlingRights.contains("Q") {
                whitePieces.filter({ $0.type == .rook && $0.position?.file == Game.size - 1 }).first?.movesCount = 1
            }
            whitePieces.filter({ $0.type == .king }).first?.movesCount += 1
        }
        
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
        let notation = Notation(moves: moves + enPassantMoves)
        
        // 6. Fullmove Number (not used)
        _ = Int(fenParts[5]) ?? 0
        
        return (board, turn, notation)
    }
}
