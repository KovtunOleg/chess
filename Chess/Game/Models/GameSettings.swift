//
//  GameSettings.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import SwiftUI

@Observable
class GameSettings: Identifiable {
    struct GameType: Hashable, CustomStringConvertible {
        enum Mode: Hashable, CaseIterable, CustomStringConvertible {
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
        
        var description: String {
            mode.description
        }
    }
    
    enum GameLevel: Hashable, CaseIterable, CustomStringConvertible {
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
    
    struct TimeControl: Hashable, CustomStringConvertible {
        enum Mode: Hashable, CaseIterable, CustomStringConvertible {
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
    
    var gameType: GameType
    var level: GameLevel
    var timeControl: TimeControl
    
    func playerCanMove(_ color: Piece.Color) -> Bool {
        switch gameType.mode {
        case .playerVsPlayer: break
        case .playerVsComputer: guard gameType.playerColor == color else { return false }
        }
        return true
    }
    
    var id: String {
       "settings"
    }
    
    init(gameType: GameType, level: GameLevel, timeControl: TimeControl) {
        self.gameType = gameType
        self.level = level
        self.timeControl = timeControl
    }
}

extension GameSettings {
    static let `default`: GameSettings = .init(gameType: .default, level: .default, timeControl: .default)
}

extension GameSettings.GameType {
    static let `default`: GameSettings.GameType  = .init(mode: .playerVsPlayer, playerColor: .white)
}

extension GameSettings.TimeControl {
    static let `default`: GameSettings.TimeControl = .init(mode: .blitz, increment: 0.0)
    static let incrementRange = 0.0...3.0
}

extension GameSettings.GameLevel {
    static let `default`: GameSettings.GameLevel = .medium
}
