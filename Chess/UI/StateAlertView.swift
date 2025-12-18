//
//  StateAlertView.swift
//  Chess
//
//  Created by Oleg Kovtun on 10.12.2025.
//

import SwiftUI

enum StateAlert: Identifiable {
    case draw(_ reason: Notation.State.DrawReason)
    case mate(_ winner: Piece.Color)
    case timeout(_ winner: Piece.Color)
    
    var id: String {
        switch self {
        case .draw: return "draw"
        case .mate: return "mate"
        case .timeout: return "timeout"
        }
    }
}

struct StateAlertView: View {
    private(set) var state : StateAlert
    var body: some View {
        VStack {
            Text({
                switch state {
                case .draw: return "Draw"
                case .mate: return "Mate"
                case .timeout: return "Timeout"
                }
            }())
            .font(.title.bold())
            
            if case let .draw(reason) = state {
                Text("by \(reason.description.lowercased())")
                    .foregroundStyle(.secondary)
                    .font(.title)
            } else if case let .timeout(winner) = state {
                Text("\(winner == .white ? "black" : "white") run out of time")
                    .foregroundStyle(.secondary)
                    .font(.title)
            }
            
            HStack {
                Image(.whiteKing)
                Text({
                    switch state {
                    case .draw: return "1/2 - 1/2"
                    case let .mate(winner): return winner == .white ? "1 - 0" : "0 - 1"
                    case let .timeout(winner): return winner == .white ? "1 - 0" : "0 - 1"
                    }
                }())
                .font(.largeTitle.bold())
                Image(.blackKing)
            }
        }
        .padding(32)
        .contentShape(Rectangle())
    }
}
