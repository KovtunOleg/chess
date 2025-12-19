//
//  RightPannelView.swift
//  Chess
//
//  Created by Oleg Kovtun on 12.12.2025.
//

import Combine
import SwiftUI

@MainActor
struct RightPannelView: View {
    @Binding private(set) var game: Game
    @Environment(\.gameSettings) var gameSettings
    @Environment(\.soundManager) var soundManager
    
    var state: Notation.State { game.notation.state }
    var moves: [Notation.Move] { game.notation.moves }
    
    var body: some View {
        ZStack {
            VStack {
                buttonsView()
                if !state.canMove {
                    gameSettingsView()
                }
                notationView()
                Spacer()
            }
            .padding(8)
        }
        .background(.gray.opacity(0.1))
        .onAppear() {
            reset()
        }
    }
}

extension RightPannelView {
    @ViewBuilder
    private func buttonsView() -> some View {
        Button(action: {
            if state.canStart {
                start()
                soundManager?.play(.gameStart)
            } else {
                reset()
                soundManager?.play(.notify)
            }
        }) {
            Text(state.canStart ? "Start" : "Reset")
                .font(.title.bold())
                .padding(4)
        }
        .animatedBorder(animate: state.canStart)
        .padding()
    }
    
    @ViewBuilder
    private func gameSettingsView() -> some View {
        @Bindable var gameSettings = gameSettings
        VStack(alignment: .leading) {
            CustomPicker(selection: $gameSettings.gameType.mode, segments: GameSettings.GameType.Mode.allCases) { mode in
                Text(mode.description)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            if case .playerVsComputer = gameSettings.gameType.mode {
                CustomPicker(selection: $gameSettings.gameType.playerColor, segments: Piece.Color.allCases) { color in
                    Image(Piece(color: color, type: .king).image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                CustomPicker(selection: $gameSettings.level, segments: GameSettings.GameLevel.allCases) { level in
                    Text(level.description)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
            }
            CustomPicker(selection: $gameSettings.timeControl.mode, segments: GameSettings.TimeControl.Mode.allCases) { mode in
                VStack(spacing: 0) {
                    let description = GameSettings.TimeControl(mode: mode, increment: gameSettings.timeControl.increment).description.split(separator: "|")
                    Label {
                        Text(description[0])
                    } icon: {
                        Image(mode.icon)
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(height: 25)
                    Text(description[1])
                        .font(Font.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 15)
                }
            }
            let incrementRange = GameSettings.TimeControl.incrementRange
            Slider(value: $gameSettings.timeControl.increment, in: incrementRange, step: 1) {
                Text("Increment")
                    .frame(height: 25)
            } minimumValueLabel: {
                Text("\(Int(incrementRange.lowerBound))")
                    .font(Font.title3.bold())
            } maximumValueLabel: {
                Text("\(Int(incrementRange.upperBound))")
                    .font(Font.title3.bold())
            }
            Toggle("Always promote to queen", isOn: $gameSettings.autoQueen)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .frame(maxWidth: .infinity)
        }
        .font(Font.title3.bold())
    }
    
    @ViewBuilder
    private func notationView() -> some View {
        ScrollView {
            let attributedText = {
                var attributedString = AttributedString("")
                for (i, fullMove) in moves.chunked(into: 2).enumerated() {
                    if fullMove.first != .unknown {
                        for (j, move) in fullMove.enumerated() {
                            let isLastMove = (i * 2 + j) + 1 == moves.count
                            var attributedMove = AttributedString((j == 0 ? "\(i + 1). " : "") + move.description + " " + (isLastMove ? state.description : ""))
                            attributedMove.font = .system(size: 14, weight: isLastMove ? .semibold : .regular)
                            attributedString.append(attributedMove)
                        }
                    }
                }
                return attributedString
            }()
            Text(attributedText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .padding(4)
    }
}

extension RightPannelView {
    private func reset() {
        do {
            game = try FENParser.parse(fen: FENParser.startPosition)

        } catch {
            guard error is FENParser.ParsingError else { print("Unknown error"); return }
            print("Invalid FEN format")
        }
    }
    
    private func start() {
        Task {
            await game.start()
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var game = Game()
    Group {
        RightPannelView(game: $game)
    }
}
