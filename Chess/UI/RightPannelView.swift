//
//  RightPannelView.swift
//  Chess
//
//  Created by Oleg Kovtun on 12.12.2025.
//

import Combine
import Flow
import SwiftUI

@MainActor
struct RightPannelView: View {
    @Binding private(set) var game: Game
    @State private var moves = [Notation.Move]()
    @State private var state = Notation.State.play
    @State private var notationCancellable: AnyCancellable?
    
    var body: some View {
        VStack {
            buttonsView()
            Spacer()
            notationView()
        }
        .background(.gray.opacity(0.1))
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }
}

extension RightPannelView {
    @ViewBuilder
    private func buttonsView() -> some View {
        Button(action: {
            reset()
        }) {
            Text("Start Game")
                .font(.title.bold())
                .padding(4)
        }
        .padding()
    }
    
    @ViewBuilder
    private func notationView() -> some View {
        ScrollView {
            HStack {
                HFlow(horizontalAlignment: .leading, verticalAlignment: .top) {
                    ForEach(moves.chunked(into: 2).enumerated(), id: \.offset) { (i, fullMove) in
                        if fullMove.first != .unknown {
                            HStack {
                                ForEach(fullMove.enumerated(), id: \.offset) { (j, move) in
                                    let isLastMove = (i * 2 + j) + 1 == moves.count
                                    Text((j == 0 ? "\(i + 1). " : "") + move.description + (isLastMove ? state.description : ""))
                                        .font(.system(size: 14, weight: isLastMove ? .semibold : .regular))
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }
}

extension RightPannelView {
    private func reset() {
        do {
            game = try FENParser.parse(fen: FENParser.startPosition)
            notationCancellable = game.notationPublisher
                .sink { notation in
                    moves = notation.moves
                    state = notation.state
                }

        } catch {
            guard error is FENParser.ParsingError else { print("Unknown error"); return }
            print("Invalid FEN format")
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var game = Game()
    Group {
        RightPannelView(game: $game)
    }
}
