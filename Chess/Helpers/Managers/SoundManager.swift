//
//  SoundManager.swift
//  Chess
//
//  Created by Oleg Kovtun on 18.12.2025.
//

import AVFoundation
import SwiftUI

enum Sound: CaseIterable {
    enum SoundError: Error {
        case notFound(String)
        case cantInitiateAudioPlayer(Error)
    }
    
    case capture
    case castle
    case check
    case gameEnd
    case gameStart
    case illegal
    case move
    case notify
    case promote
    
    var fileName: String {
        switch self {
        case .capture: return "capture"
        case .castle: return "castle"
        case .check: return "check"
        case .gameEnd: return "game-end"
        case .gameStart: return "game-start"
        case .illegal: return "illegal"
        case .move: return "move"
        case .notify: return "notify"
        case .promote: return "promote"
        }
    }
}

protocol SoundManagerProtocol {
    func play(_ sound: Sound) throws
}

class SoundManager {
    static let shared = try? SoundManager()
    
    private var sounds = [Sound: AVAudioPlayer]()
    
    init() throws {
        Task(priority: .high) {
            sounds = try Sound.allCases.reduce(into: [:]) { result, sound in
                do {
                    guard let path = Bundle.main.path(forResource: sound.fileName, ofType: "mp3") else { throw Sound.SoundError.notFound(sound.fileName) }
                    result[sound] = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                } catch {
                    throw Sound.SoundError.cantInitiateAudioPlayer(error)
                }
            }
        }
    }
}

extension SoundManager: SoundManagerProtocol {
    func play(_ sound: Sound) {
        Task(priority: .high) {
            sounds[sound]?.play()
        }
    }
}
