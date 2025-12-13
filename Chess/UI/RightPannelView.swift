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
    @Environment(\.gameSettings) var gameSettings
    @State private var moves = [Notation.Move]()
    @State private var state = Notation.State.idle
    @State private var notationCancellable: AnyCancellable?
    
    var body: some View {
        VStack {
            buttonsView()
            gameSettingsView()
            notationView()
            Spacer()
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
    private func gameSettingsView() -> some View {
        @Bindable var gameSettings = gameSettings
        VStack(alignment: .leading, spacing: 0) {
            CustomPicker(selection: $gameSettings.gameType, segments: GameSettings.GameType.allCases) { type in
                Text(type.description)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .font(Font.title2.bold())
            }
            .padding(4)
            if case .playerVsComputer = gameSettings.gameType {
                CustomPicker(selection: $gameSettings.playerColor, segments: Piece.Color.allCases) { color in
                    Image(Piece(color: color, type: .king).image)
                        .resizable()
                        .scaledToFit()
                }
                .padding(4)
            }
        }
        .disabled(!state.isEnded)
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
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }
}

extension RightPannelView {
    private func reset() {
        do {
            moves.removeAll()
            state = .idle
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
