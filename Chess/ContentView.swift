//
//  ContentView.swift
//  Chess
//
//  Created by Oleg Kovtun on 01.12.2025.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct ContentView: View {
    @State private var game = Game()
    @State private var moves: [Position]?
    @State private var selected: Piece? {
        didSet {
            moves = {
                guard let selected else { return nil }
                return game.moves(for: selected)
            }()
        }
    }
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
            game.reset()
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
        let (rank, file) = (square.position.rank, square.position.file)
        let isLight = (rank + file) % 2 == 1
        let baseColor = isLight ? Color(white: 0.95) : Color(white: 0.25)
        ZStack {
            Rectangle()
                .fill(baseColor)
                .frame(width: size, height: size)
            
            if let piece = square.piece {
                Image(piece.image)
                    .resizable()
                    .scaledToFit()
                    .opacity(selected == piece ? 0 : 1)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture(coordinateSpace: .named(Self.boardCoordinateSpace))
                                .onChanged { gesture in
                                    selected = game.turn == piece.color ? piece : nil
                                    selected?.dragPosition = gesture.location
                                }
                                .onEnded { gesture in
                                    selected = nil
                                    guard let destination = getSquare(at: gesture.location, size: size) else { return }
                                    game.move(piece, to: destination)
                                },
                            TapGesture()
                                .onEnded {
                                    selected = game.turn == piece.color ? piece : nil
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
                                selected = nil
                                guard let destination = getSquare(at: gesture.location, size: size) else { return }
                                game.move(piece, to: destination)
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
                            selected = nil
                            game.move(piece, to: square)
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
                let letter = UnicodeScalar("A").value + UInt32(file)
                Text(String(UnicodeScalar(letter)!))
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
                Text("\(rank + 1)")
                    .font(.caption2)
                    .foregroundColor(.black.opacity(0.5))
                    .padding(4)
                Spacer()
            }
        }
    }
}

extension ContentView: NotationDelegate {
    func notationDidChange(_ notation: Notation) {
        
    }
}

extension ContentView {
    private func getPoint(for square: Square, size: CGFloat) -> CGPoint {
        CGPoint(x: size * Double(square.position.file) + size / 2,
                y: size * Double(Game.size - square.position.rank) - size / 2)
    }
    
    private func getSquare(at point: CGPoint, size: CGFloat) -> Square? {
        let file = Int(point.x / size)
        let rank = Game.size - Int(point.y / size) - 1
        guard point.x >= 0, point.y >= 0, rank >= 0, rank < Game.size, file >= 0, file < Game.size else { return nil }
        return game.square(at: Position(rank: rank, file: file))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewLayout(.sizeThatFits)
        }
    }
}
