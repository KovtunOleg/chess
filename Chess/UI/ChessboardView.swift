//
//  Chessboard.swift
//  Chess
//
//  Created by Oleg Kovtun on 09.12.2025.
//

import SwiftUI

@MainActor struct ChessboardView: View {
    private typealias Promoted = (piece: Piece, position: Position)
    
    @State private var game: Game
    @State private var moves: [Position]?
    @State private var selected: Piece? {
        didSet {
            Task {
                moves = await {
                    guard let selected else { return nil }
                    return await game.moves(for: selected)
                }()
            }
        }
    }
    @State private var promoted: Promoted?
    @State private var checked: Piece?
    private static let boardCoordinateSpace = "board"
    
    init(_ game: Game) {
        self.game = game
    }
    
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
        .onAppear {
            do {
                game = try FENParser.parse(fen: FENParser.startPosition, delegate: self)
                game.onPromote = { pawn, position in
                    Task {
                        promoted = (pawn, position)
                        while promoted?.piece.type == .pawn {
                            try? await Task.sleep(for: .milliseconds(1))
                        }
                        let copy = promoted?.piece.copy
                        promoted = nil
                        return copy ?? pawn
                    }
                }
            } catch {
                guard error is FENParser.ParsingError else { print("Unknown error"); return }
                print("Invalid FEN format")
            }
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
                                    Task {
                                        guard selected != nil else { return }
                                        selected = nil
                                        guard let destination = getSquare(at: gesture.location, size: size) else { return }
                                        await game.move(piece, to: destination)
                                    }
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
                                Task {
                                    guard selected != nil else { return }
                                    selected = nil
                                    guard let destination = getSquare(at: gesture.location, size: size) else { return }
                                    await game.move(piece, to: destination)
                                }
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
                            Task {
                                guard let piece = selected else { return }
                                selected = nil
                                await game.move(piece, to: square)
                            }
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
            let pieces = types.map { Piece(color: game.turn, type: $0) }
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
            .position(center)
        }
    }
}

extension ChessboardView: NotationDelegate {
    func notation(_ notation: Notation, didAddMove move: Notation.Move, state: Notation.State) {
        Task { @MainActor in
            switch state {
            case .check, .mate:
                checked = game.board.pieces.first(where: { $0.color == game.turn && $0.type == .king })
            default:
                checked = nil
            }
        }
    }
}

extension ChessboardView {
    private func canSelect(_ piece: Piece) -> Bool {
        promoted == nil && piece.color == game.turn
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
}

struct ChessboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChessboardView(Game())
                .previewLayout(.sizeThatFits)
        }
    }
}
