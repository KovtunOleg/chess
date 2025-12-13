//
//  ChessApp.swift
//  Chess
//
//  Created by Oleg Kovtun on 01.12.2025.
//

import SwiftUI

@main
struct ChessApp: App {
    @State private var window: NSWindow?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowAccessor(window: $window))
                .onChange(of: window) { _, newWindow in
                    // set the aspect ratio for the window's content area
                    guard let size = newWindow?.contentView?.frame.size else { return }
                    newWindow?.contentAspectRatio = NSSize(width: size.width, height: size.height)
                }
        }
    }
}
