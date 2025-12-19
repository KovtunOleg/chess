//
//  OpeningsTrie.swift
//  Chess
//
//  Created by Oleg Kovtun on 20.12.2025.
//

final class OpeningsTrie {
    static let shared = try? OpeningsBookParser.parse()
    
    typealias Line = (title: String, moves: [String])
    
    private(set) var title: String?
    private(set) weak var parent: OpeningsTrie?
    private(set) var children = [String: OpeningsTrie]()
    private(set) var movesCount = 0

    init(title: String? = nil, parent: OpeningsTrie? = nil, movesCount: Int = 0) {
        self.title = title
        self.parent = parent
        self.movesCount = movesCount
    }
    
    func insert(_ line: Line) {
        var root = self
        for move in line.moves {
            if root.children[move] == nil {
                root.children[move] = OpeningsTrie(title: line.title, parent: root, movesCount: root.movesCount + 1)
            }
            root = root.children[move]!
        }
    }

    func search(_ moves: [String]) -> OpeningsTrie? {
        var root = self
        for move in moves {
            guard let next = root.children[move] else { return nil }
            root = next
        }
        return root
    }
}
