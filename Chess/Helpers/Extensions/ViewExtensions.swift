//
//  ViewExtensions.swift
//  Chess
//
//  Created by Oleg Kovtun on 10.12.2025.
//

import SwiftUI

extension View {
    func onHover<Content: View>(@ViewBuilder _ modify: @escaping (Self) -> Content) -> some View {
        modifier(HoverModifier { modify(self) })
    }
    
    func sizeReader(size: Binding<CGSize>) -> some View {
        modifier(SizeReader(size: size))
    }
}

private struct HoverModifier<Result: View>: ViewModifier {
    @ViewBuilder let modifier: () -> Result
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        (isHovering ? AnyView(modifier()) : AnyView(content))
            .onHover {
                isHovering = $0
            }
    }
}

struct SizeReader: ViewModifier {
    @Binding var size: CGSize

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self, of: \.size) {
                size = $0
            }
    }
}
