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
    private typealias Time = (black: Double, white: Double)
    private typealias CapturedPieces = (black: SortedArray<Piece>, white: SortedArray<Piece>)
    
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
    @State private var capturedPieces: CapturedPieces = (black: SortedArray([]), white: SortedArray([]))
    @State private var cpu = CPU()
    @State private var timer: Timer?
    @State private var time: Time?
    @State private var notationCancellable: AnyCancellable?
    
    private var state: Notation.State { game.notation.state }
    
    private static let boardCoordinateSpace = "board"
    
    var body: some View {
        GeometryReader { geometry in
            let annotationSize = 20.0
            let sideSize: CGFloat = 40.0
            let size = min(geometry.size.width, geometry.size.height)
            let boardSize = size - annotationSize - 2 * sideSize
            let squareSize = boardSize / CGFloat(Game.size)
            let rotate = gameSettings.rotateBoard
            VStack(spacing: 0) {
                sideView(color: rotate ? .white : .black)
                    .frame(width: boardSize + annotationSize, height: sideSize)
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
                            .frame(height: annotationSize)
                    }
                    .frame(width: boardSize + annotationSize, height: boardSize)
                }
                sideView(color: rotate ? .black : .white)
                    .frame(width: boardSize + annotationSize, height: sideSize)
            }
            .frame(width: size, height: boardSize + annotationSize + 2 * sideSize)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .sheet(item: $stateAlert) { item in
            StateAlertView(state: item)
                .onTapGesture {
                    stateAlert = nil
                }
                .task {
                    stopTimer()
                    stopCPU()
                }
        }
        .onChange(of: game) { _, _ in
            resetGame()
        }
        .onChange(of: gameSettings.timeControl) { _, _ in
            resetTime()
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
        .overlay {
            if state.canStart || promoted != nil {
                Rectangle()
                    .fill(Color.black.opacity(0.25))
                    .cornerRadius(8)
            }
        }
        .rotationEffect(gameSettings.rotateBoard ? .radians(.pi) : .zero)
    }

    @ViewBuilder
    private func squareView(square: Square, size: CGFloat) -> some View {
        let baseColor = square.position.isLight ? Color(white: 0.95) : Color(white: 0.25)
        ZStack {
            Rectangle()
                .fill(baseColor)
                .border(.green.opacity(lastMove?.from == square.position ? 0.5 : 1), width: lastMove?.from == square.position || lastMove?.to == square.position ? 4 : 0)
                .frame(width: size, height: size)
            
            if let piece = square.piece {
                pieceView(for: piece, size: size)
                    .opacity(selected == piece || promoted?.piece == piece ? 0 : 1)
                    .shadow(color: checked == piece ? .red : .clear, radius: 10)
                    .rotationEffect(gameSettings.rotateBoard ? .radians(.pi) : .zero)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture(coordinateSpace: .named(Self.boardCoordinateSpace))
                                .onChanged { gesture in
                                    selected = canSelect(piece) ? piece : nil
                                    selected?.dragPosition = gesture.location
                                }
                                .onEnded { gesture in
                                    guard let destination = getSquare(at: gesture.location, size: size) else {
                                        selected = nil
                                        return
                                    }
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
            pieceView(for: piece, size: size)
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
                                guard let destination = getSquare(at: gesture.location, size: size) else {
                                    selected = nil
                                    return
                                }
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
            let range = gameSettings.rotateBoard ? Array((0..<Game.size).reversed()) : Array(0..<Game.size)
            ForEach(range, id: \.self) { file in
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
            let range = gameSettings.rotateBoard ? Array(0..<Game.size) : Array((0..<Game.size).reversed())
            ForEach(range, id: \.self) { rank in
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
            let rotate = gameSettings.rotateBoard
            let types: [Piece.`Type`] = [.queen, .rook, .bishop, .knight]
            let pieces = {
                var pieces = types.map { Piece(color: game.turn, type: $0) }
                if (piece.color == .black && !rotate) { pieces.reverse() }
                return pieces
            }()
            let center = CGPoint(x: getPoint(for: game.square(at: position), size: size).x,
                                 y: (piece.color == .white || rotate ? 0 : size * CGFloat(pieces.count)) + size * CGFloat(pieces.count) / 2)
            VStack(spacing: 0) {
                ForEach(pieces, id: \.self) { piece in
                    pieceView(for: piece, size: size)
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
            .frame(width: size)
        }
    }
    
    @ViewBuilder
    private func pieceView(for piece: Piece, size: CGFloat) -> some View {
        Image(piece.image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
    
    @ViewBuilder
    private func timerView(color: Piece.Color) -> some View {
        if let time {
            let total = color == .white ? time.white : time.black
            let minutes = Int(total / Double(secondsInMinute))
            let seconds = Int(total.truncatingRemainder(dividingBy: Double(secondsInMinute)))
            let milliseconds = Int((total - Double(minutes) * Double(secondsInMinute) - Double(seconds)) * 100.0)
            let format = "%02d"
            let defaultState = game.turn == color && timer != nil
            let criticalTime = 20.0
            Label {
                HStack(alignment: .bottom, spacing: 0) {
                    Text("\(String(format: format, minutes)):\(String(format: format, seconds))")
                        .font(.largeTitle.monospacedDigit())
                    Text("." + String(format: format, milliseconds))
                        .font(.caption.monospacedDigit())
                        .frame(height: 20)
                        .foregroundStyle(defaultState ? (total > criticalTime ? .gray : .red) : .gray)
                }
            } icon: {
                Image(systemName: "clock").bold()
            }
            .frame(width: 140, height: 40)
            .foregroundStyle(defaultState ? (total > criticalTime ? .black : .red) : .gray)
        }
    }
    
    @ViewBuilder
    private func capturedPiecesView(color: Piece.Color) -> some View {
        GeometryReader { geometry in
            let size = geometry.size.height
            let offset = size * 0.75
            HStack {
                let pieces = color == .white ? capturedPieces.white : capturedPieces.black
                ForEach(pieces.elements, id: \.self) { piece in
                    pieceView(for: piece, size: size)
                        .shadow(color: color == .black ? .black : .white, radius: 1)
                }
                .padding(.leading, -offset)
            }
            .padding(.init(top: 0, leading: offset, bottom: 0, trailing: offset))
        }
    }
    
    @ViewBuilder
    private func sideView(color: Piece.Color) -> some View {
        HStack(spacing: 0) {
            capturedPiecesView(color: color)
                .frame(maxWidth: .infinity)
            timerView(color: color)
        }
    }
}

extension ChessboardView {
    // MARK: Game
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
            guard let (_, moves) = await cpu.search(game: game.copy, gameSettings: gameSettings) else { return }
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
    
    // MARK: Positioning
    private func getPoint(for square: Square, size: CGFloat) -> CGPoint {
        let rotate = gameSettings.rotateBoard
        return CGPoint(x: size * Double(rotate ? Game.size - square.position.file : square.position.file) + (rotate ? -1 : 1) * size / 2,
                y: size * Double(rotate ? square.position.rank : Game.size - square.position.rank) + (rotate ? 1 : -1) * size / 2)
    }
    
    private func getSquare(at point: CGPoint, size: CGFloat) -> Square? {
        let rotate = gameSettings.rotateBoard
        let position = Position(rank: rotate ? Int(point.y / size): Game.size - Int(point.y / size) - 1,
                                file: rotate ? Game.size - Int(point.x / size) - 1 : Int(point.x / size))
        guard position.isValid else { return nil }
        return game.square(at: position)
    }

    private func canSelect(_ piece: Piece) -> Bool {
        promoted == nil && piece.color == game.turn &&
        state.canMove && gameSettings.playerCanMove(piece.color)
    }
    
    private func resetGame() {
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
                tick()
            }
        resetTime()
        stopTimer()
        stopCPU()
        selected = nil
        promoted = nil
        checked = nil
        lastMove = nil
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
        case let .move(piece, position, captured, _):
            lastMove = (from: piece.position!, to: position)
            guard let captured else { return }
            switch game.turn {
            case .black:
                var sorted = capturedPieces.white
                sorted.insert(captured)
                capturedPieces = (black: capturedPieces.black, white: sorted)
            case .white:
                var sorted = capturedPieces.black
                sorted.insert(captured)
                capturedPieces = (black: sorted, white: capturedPieces.white)
            }
        case let .castle(king, _, newKingPosition, _, _):
            lastMove = (from: king.position!, to: newKingPosition)
        case .unknown:
            lastMove = nil
        }
    }
    
    // MARK: Timer
    private func tick() {
        guard !game.notation.moves.isEmpty else { return }
        if timer == nil {
            runTimer()
        }
        guard let time else { return }
        switch game.turn {
        case .white:
            self.time = (black: time.black + gameSettings.timeControl.increment, white: time.white)
        case .black:
            self.time = (black: time.black, white: time.white + gameSettings.timeControl.increment)
        }
    }
    
    private func runTimer() {
        let timeInterval = 0.01
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
            Task { @MainActor in
                guard let time else { return }
                switch game.turn {
                case .white:
                    self.time = (black: time.black, white: max(time.white - timeInterval, 0))
                    guard self.time?.white == 0 else { break }
                    stateAlert = .timeout(.black)
                case .black:
                    self.time = (black: max(time.black - timeInterval, 0), white: time.white)
                    guard self.time?.black == 0 else { break }
                    stateAlert = .timeout(.white)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func stopCPU() {
        cpu.cancel()
    }
    
    private func resetTime() {
        time = Time(black: gameSettings.timeControl.time * Double(secondsInMinute), white: gameSettings.timeControl.time * Double(secondsInMinute))
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var game = Game()
    Group {
        ChessboardView(game: $game)
    }
}
