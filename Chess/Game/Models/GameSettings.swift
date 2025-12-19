//
//  GameSettings.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import SwiftUI

protocol GameSettingsProtocol {
    static func read() -> GameSettings
}

@Observable
class GameSettings: Identifiable, Codable {
    struct GameType: Hashable, CustomStringConvertible, Codable {
        enum Mode: Hashable, CaseIterable, CustomStringConvertible, Codable {
            case playerVsPlayer
            case playerVsComputer
            
            var description: String {
                switch self {
                case .playerVsPlayer: return "PvP"
                case .playerVsComputer: return "PvC"
                }
            }
        }
        var mode: Mode
        var playerColor: Piece.Color
        var computerColor: Piece.Color { playerColor == .white ? .black : .white }
        
        var description: String {
            mode.description
        }
    }
    
    enum GameLevel: Hashable, CaseIterable, CustomStringConvertible, Codable {
        case easy
        case medium
        case hard
        
        var description: String {
            switch self {
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            }
        }
        
        var depth: Int {
            switch self {
            case .easy: return 3
            case .medium: return 4
            case .hard: return 5
            }
        }
    }
    
    struct TimeControl: Hashable, CustomStringConvertible, Codable {
        enum Mode: Hashable, CaseIterable, CustomStringConvertible, Codable {
            case bullet
            case blitz
            case rapid
            
            var description: String {
                switch self {
                case .bullet: return "Bullet"
                case .blitz: return "Blitz"
                case .rapid: return "Rapid"
                }
            }
            
            var icon: ImageResource {
                switch self {
                case .bullet: return .bullet
                case .blitz: return .blitz
                case .rapid: return .rapid
                }
            }
        }
        
        var mode = Mode.blitz
        var increment = 0.0
        
        var time: CGFloat {
            switch mode {
            case .bullet: return 1
            case .blitz: return 3
            case .rapid: return 10
            }
        }
        
        var description: String {
            mode.description + "|\(Int(time)) min (+\(Int(increment)) sec)"
        }
    }
    
    var gameType: GameType {
        didSet { GameSettings.save(self) }
    }
    var level: GameLevel = .medium {
        didSet { GameSettings.save(self) }
    }
    var timeControl: TimeControl = .default {
        didSet { GameSettings.save(self) }
    }
    var autoQueen: Bool = false {
        didSet { GameSettings.save(self) }
    }
    
    func playerCanMove(_ color: Piece.Color) -> Bool {
        switch gameType.mode {
        case .playerVsPlayer: break
        case .playerVsComputer: guard gameType.playerColor == color else { return false }
        }
        return true
    }
    
    var rotateBoard: Bool {
        switch gameType.playerColor {
        case .white: return false
        case .black: return true
        }
    }
    
    var id: String { Self.key }
    
    init(gameType: GameType, level: GameLevel, timeControl: TimeControl, autoQueening: Bool) {
        self.gameType = gameType
        self.level = level
        self.timeControl = timeControl
        self.autoQueen = autoQueening
    }
}

extension GameSettings: GameSettingsProtocol {
    static let key = "settings"
    static private func save(_ settings: GameSettings) {
        UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: key)
    }
    
    static func read() -> GameSettings {
        guard let data = UserDefaults.standard.data(forKey: key), let settings = try? JSONDecoder().decode(Self.self, from: data) else {
            return .init(gameType: .default,
                         level: .default,
                         timeControl: .default,
                         autoQueening: false)
        }
        return settings
    }
}

extension GameSettings.GameType {
    static let `default`: GameSettings.GameType  = .init(mode: .playerVsPlayer,
                                                         playerColor: .white)
}

extension GameSettings.TimeControl {
    static let `default`: GameSettings.TimeControl = .init(mode: .blitz,
                                                           increment: 0.0)
    static let incrementRange = 0.0...3.0
}

extension GameSettings.GameLevel {
    static let `default`: GameSettings.GameLevel = .medium
}
