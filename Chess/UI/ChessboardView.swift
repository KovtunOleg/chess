//
//  Chessboard.swift
//  Chess
//
//  Created by Oleg Kovtun on 09.12.2025.
//

import Combine
import SwiftUI

@MainActor
struct ChessboardView: View {
    private typealias Move = (from: Position, to: Position)
    private typealias Promoted = (piece: Piece, position: Position)
    
    @Binding private(set) var game: Game
    @Environment(\.gameSettings) var gameSettings
    @State private var moves: [Position]?
    @State private var selected: Piece? {
        didSet {
            guard let selected else {
                moves = nil
                return
            }
            Task {
                moves = await {
                    return await game.moves(for: selected)
                }()
            }
        }
    }
    @State private var promoted: Promoted?
    @State private var checked: Piece?
    @State private var lastMove: Move?
    @State private var stateAlert: StateAlert?
    @State private var cpu = CPU()
    @State private var notationCancellable: AnyCancellable?
    
    private static let boardCoordinateSpace = "board"
    
    var body: some View {
        GeometryReader { geometry in
            let annotationSize = 20.0
            let size = min(geometry.size.width, geometry.size.height) + annotationSize
            let boardSize = size - annotationSize
            let squareSize = boardSize / CGFloat(Game.size)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    rankAnnotationView()
                    Spacer(minLength: annotationSize)
                }
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        boardView(squareSize: squareSize)
                        movesView(size: squareSize)
                        selectedPieceView(size: squareSize)
                        promoteView(size: squareSize)
                    }
                    .coordinateSpace(name: Self.boardCoordinateSpace)
                    fileAnnotationView()
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .padding()
        .sheet(item: $stateAlert) { item in
            StateAlertView(state: item)
                .onTapGesture {
                    stateAlert = nil
                }
        }
        .onChange(of: game) { _, _ in
            reset()
        }
    }
    
    @ViewBuilder
    private func boardView(squareSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach((0..<Game.size).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach((0..<Game.size), id: \.self) { file in
                        squareView(square: game.square(at: Position(rank: rank, file: file)), size: squareSize)
                    }
                }
            }
        }
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func squareView(square: Square, size: CGFloat) -> some View {
        let baseColor = square.position.isLight ? Color(white: 0.95) : Color(white: 0.25)
        ZStack {
            Rectangle()
                .fill(baseColor)
                .border(.blue.opacity(lastMove?.from == square.position ? 0.5 : 1), width: lastMove?.from == square.position || lastMove?.to == square.position ? 4 : 0)
                .frame(width: size, height: size)
            
            if let piece = square.piece {
                Image(piece.image)
                    .resizable()
                    .scaledToFit()
                    .opacity(selected == piece || promoted?.piece == piece ? 0 : 1)
                    .shadow(color: checked == piece ? .red : .clear, radius: 10)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture(coordinateSpace: .named(Self.boardCoordinateSpace))
                                .onChanged { gesture in
                                    selected = canSelect(piece) ? piece : nil
                                    selected?.dragPosition = gesture.location
                                }
                                .onEnded { gesture in
                                    guard let destination = getSquare(at: gesture.location, size: size) else { return }
                                    playerMove(piece, to: destination)
                                },
                            TapGesture()
                                .onEnded {
                                    selected = canSelect(piece) ? piece : nil
                                    selected?.dragPosition = getPoint(for: square, size: size)
                                }
                            )
                    )
            }
        }
    }
    
    @ViewBuilder
    private func selectedPieceView(size: CGFloat) -> some View {
        if let piece = selected {
            Image(piece.image)
                .resizable()
                .scaledToFit()
                .position(piece.dragPosition)
                .shadow(color: .green, radius: 10)
                .frame(width: size, height: size)
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { gesture in
                                selected?.dragPosition = gesture.location
                            }
                            .onEnded { gesture in
                                guard let destination = getSquare(at: gesture.location, size: size) else { return }
                                playerMove(piece, to: destination)
                            },
                        TapGesture()
                            .onEnded {
                                selected = nil
                            }
                        )
                )
        }
    }
    
    @ViewBuilder
    private func movesView(size: CGFloat) -> some View {
        if let moves {
            ForEach(moves, id: \.self) { position in
                let square = game.square(at: position)
                let center = getPoint(for: square, size: size)
                Rectangle()
                    .fill(Color.clear)
                    .overlay {
                        ZStack {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                            Circle()
                                .fill(.gray.opacity(0.5))
                                .frame(width: size / 2, height: size / 2)
                        }
                        .onTapGesture {
                            guard let piece = selected else { return }
                            playerMove(piece, to: square)
                        }
                    }
                    .position(center)
                    .frame(width: size, height: size)
            }
        }
    }
    
    @ViewBuilder
    private func fileAnnotationView() -> some View {
        HStack {
            ForEach((0..<Game.size), id: \.self) { file in
                Spacer()
                Text(file.fileString.uppercased())
                    .font(.caption2)
                    .foregroundColor(.black.opacity(0.5))
                    .padding(4)
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func rankAnnotationView() -> some View {
        VStack {
            ForEach((0..<Game.size).reversed(), id: \.self) { rank in
                Spacer()
                Text(rank.rankString)
                    .font(.caption2)
                    .foregroundColor(.black.opacity(0.5))
                    .padding(4)
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func promoteView(size: CGFloat) -> some View {
        if let piece = promoted?.piece, let position = promoted?.position {
            let types: [Piece.`Type`] = [.queen, .rook, .bishop, .knight]
            let pieces = {
                var pieces = types.map { Piece(color: game.turn, type: $0) }
                if (piece.color == .black) { pieces.reverse() }
                return pieces
            }()
            let center = CGPoint(x: getPoint(for: game.square(at: position), size: size).x,
                                 y: (piece.color == .white ? 0 : size * CGFloat(pieces.count)) + size * CGFloat(pieces.count) / 2)
            VStack(spacing: 0) {
                ForEach(pieces, id: \.self) { piece in
                    Image(piece.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .onHover { view in
                            view
                                .shadow(color: .green, radius: 10)
                        }
                        .onTapGesture {
                            withAnimation {
                                promoted = (piece, position)
                            }
                        }
                }
            }
            .background(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: -2)
                    .stroke(.black.opacity(0.5), lineWidth: 4)
            )
            .position(center)
        }
    }
}

extension ChessboardView {
    func playerMove(_ piece: Piece, to square: Square) {
        Task {
            guard selected != nil else { return }
            selected = nil
            await game.move(piece, to: square)
        }
    }
    
    func cpuMoveIfNeeded() {
        guard !gameSettings.playerCanMove(game.turn) else { return }
        Task {
            let (_, moves) = await cpu.dfs(game: game.copy, depth: 3)
            var piece: Piece?, square: Square?
            switch moves.first {
            case let .move(_piece, position, _, _):
                piece = _piece
                square = game.square(at: position)
            case let .castle(king, _, newKingPosition, _, _):
                piece = king
                square = game.square(at: newKingPosition)
            default:
                break
            }
            guard let piece, let square else { return }
            await game.move(piece, to: square, force: true)
        }
    }
    
    private func canSelect(_ piece: Piece) -> Bool {
        promoted == nil && piece.color == game.turn &&
        game.notation.state.canMove && gameSettings.playerCanMove(piece.color)
    }
    
    private func getPoint(for square: Square, size: CGFloat) -> CGPoint {
        CGPoint(x: size * Double(square.position.file) + size / 2,
                y: size * Double(Game.size - square.position.rank) - size / 2)
    }
    
    private func getSquare(at point: CGPoint, size: CGFloat) -> Square? {
        let position = Position(rank: Game.size - Int(point.y / size) - 1, file: Int(point.x / size))
        guard position.isValid else { return nil }
        return game.square(at: position)
    }
    
    private func reset() {
        game.onPromote = { pawn, position in
            Task {
                guard gameSettings.playerCanMove(pawn.color) else { return Piece(color: pawn.color, type: .queen) } // for CPU default to queen
                promoted = (pawn, position)
                while promoted?.piece.type == .pawn {
                    try? await Task.sleep(for: .milliseconds(1))
                }
                let copy = promoted?.piece.copy
                promoted = nil
                return copy ?? pawn
            }
        }
        notationCancellable = game.notationPublisher
            .sink { notation in
                update(notation)
                cpuMoveIfNeeded()
            }
        selected = nil
        promoted = nil
        checked = nil
        lastMove = nil
        cpuMoveIfNeeded()
    }
    
    private func update(_ notation: Notation) {
        switch notation.state {
        case .check, .mate:
            if case let .mate(winner) = notation.state {
                stateAlert = .mate(winner)
            }
            checked = game.board.pieces.first(where: { $0.color == game.turn && $0.type == .king })
        default:
            if case let .draw(reason) = notation.state {
                stateAlert = .draw(reason)
            }
            checked = nil
        }
        switch notation.move {
        case let .move(piece, position, _, _):
            lastMove = (from: piece.position!, to: position)
        case let .castle(king, _, newKingPosition, _, _):
            lastMove = (from: king.position!, to: newKingPosition)
        case .unknown:
            lastMove = nil
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var game = Game()
    Group {
        ChessboardView(game: $game)
    }
}
