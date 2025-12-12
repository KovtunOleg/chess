//
//  ArrayExtensions.swift
//  Chess
//
//  Created by Oleg Kovtun on 12.12.2025.
//

import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
