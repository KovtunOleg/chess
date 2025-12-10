//
//  StateAlert.swift
//  Chess
//
//  Created by Oleg Kovtun on 10.12.2025.
//

import SwiftUI

enum StateAlert: Identifiable {
    case mate(_ winner: Piece.Color)
    case draw(_ reason: Notation.State.DrawReason)

    var id: String {
        switch self {
        case .mate: return "mate"
        case .draw: return "draw"
        }
    }
    
    var title: Text {
        Text({
            switch self {
            case .mate:
                return "Mate"
            case .draw:
                return "Draw"
            }
        }())
    }

    var message: Text? {
        switch self {
        case let .mate(winner):
            return Text(winner == .white ? "White wins!" : "Black wins!")
        case let .draw(reason):
            return Text(reason.description)
        }
    }
}
