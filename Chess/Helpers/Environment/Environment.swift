//
//  EnvironmentValues.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var gameSettings = GameSettings.default
    @Entry var soundManager = SoundManager.shared
}
