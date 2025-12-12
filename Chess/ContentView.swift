//
//  ContentView.swift
//  Chess
//
//  Created by Oleg Kovtun on 01.12.2025.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @State private var game = Game()
    
    var body: some View {
        let minBoardSize = 500.0
        let minRightPannelSize = 200.0
        GeometryReader { geometry in
            let boardSize = max(minBoardSize, min(geometry.size.width, geometry.size.height))
            let rightPannelSize = max(minRightPannelSize, geometry.size.width - boardSize)
            HStack(spacing: 0) {
                ChessboardView(game: $game)
                    .frame(width: boardSize, height: boardSize)
                RightPannelView(game: $game)
                    .frame(width: rightPannelSize)
                    .frame(minWidth: minRightPannelSize)
            }
        }
        .frame(minWidth: minBoardSize + minRightPannelSize, minHeight: minBoardSize)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    Group {
        ContentView()
    }
}
