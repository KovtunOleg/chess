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
    @State private var boardSize = CGSize.zero
    @State private var rightPannelSize = CGSize.zero
    
    var body: some View {
        let minBoardSize = 500.0
        let minRightPannelSize = 200.0
        GeometryReader { geometry in
            let boardSize = max(minBoardSize, min(geometry.size.width, geometry.size.height))
            let rightPannelSize = max(minRightPannelSize, geometry.size.width - boardSize)
            HStack(spacing: 0) {
                ChessboardView(game: $game)
                    .frame(width: boardSize, height: boardSize)
                VStack {
                    HStack {
                        Button(action: {
                            reset()
                        }) {
                            Text("Start Game")
                                .font(.title.bold())
                                .padding(4)
                        }
                        .padding()
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: rightPannelSize)
                .frame(minWidth: minRightPannelSize)
            }
        }
        .frame(minWidth: minBoardSize + minRightPannelSize, minHeight: minBoardSize)
    }
}

extension ContentView {
    private func reset() {
        do {
            game = try FENParser.parse(fen: FENParser.startPosition)

        } catch {
            guard error is FENParser.ParsingError else { print("Unknown error"); return }
            print("Invalid FEN format")
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    Group {
        ContentView()
    }
}
