//
//  StateAlertView.swift
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
}

struct StateAlertView: View {
    private(set) var state : StateAlert
    var body: some View {
        VStack {
            Text({
                switch state {
                case .mate:
                    return "Mate"
                case .draw:
                    return "Draw"
                }
            }())
            .font(.title.bold())
            
            if case let .draw(reason) = state {
                Text("by \(reason.description.lowercased())")
                    .foregroundStyle(.secondary)
                    .font(.title)
            }
            
            HStack {
                Image(.whiteKing)
                Text({
                    switch state {
                    case let .mate(winner): return winner == .white ? "1 - 0" : "0 - 1"
                    case .draw: return "1/2 - 1/2"
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
