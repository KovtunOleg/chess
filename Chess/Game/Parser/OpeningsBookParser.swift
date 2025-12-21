//
//  OpeningsBookParser.swift
//  Chess
//
//  Created by Oleg Kovtun on 20.12.2025.
//

import Foundation

final class OpeningsBookParser {
    private static let fileName = "chess_openings"
    
    enum ParsingError: Error {
        case missingFile(String)
        case invalidPGNFormat(String)
    }
    
    static func parse() throws -> OpeningsTrie {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: "csv") else {
            throw ParsingError.missingFile(fileName)
        }
        let content = try String(contentsOf: fileURL, encoding: .utf8).split(separator: "\n").map(String.init)
        let trie = OpeningsTrie()
        for line in content.dropFirst() {
            guard let match = try /"(?<ECO>.*)","(?<name>.*)","(?<moves>.*)"/.wholeMatch(in: line) else {
                throw ParsingError.invalidPGNFormat(line)
            }
            trie.insert((title: "\(match.name)",
                         moves: PGNParser.parseMovesAndResult(pgn: "\(match.moves)").moves))
        }
        return trie
    }
}
