//
//  GameSettings.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import SwiftUI

@Observable
class GameSettings: Identifiable {
    enum GameType: Hashable, CaseIterable, CustomStringConvertible {
        case playerVsPlayer
        case playerVsComputer
        
        var description: String {
            switch self {
            case .playerVsPlayer: return "PvP"
            case .playerVsComputer: return "PvC"
            }
        }
    }
    
    var gameType: GameType = .playerVsPlayer
    var playerColor: Piece.Color = .white
    
    func playerCanMove(_ color: Piece.Color) -> Bool {
        switch gameType {
        case .playerVsPlayer: break
        case .playerVsComputer: guard playerColor == color else { return false }
        }
        return true
    }
    
    var id: String {
       "settings"
    }
}
