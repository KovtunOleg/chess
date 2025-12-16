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
    
    func animatedBorder(animate: Bool = true, cornerRadius: CGFloat = 8.0) -> some View {
        modifier(AnimatedBorder(animate: animate, cornerRadius: cornerRadius))
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

struct AnimatedBorder: ViewModifier {
    @State private var update: Bool = false
    private(set) var animate: Bool
    private(set) var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background {
                if animate {
                    GeometryReader { geometry in
                        let dash = 50.0
                        let lineWidth = 2.0
                        let perimeter = 2 * (geometry.size.width + geometry.size.height + .pi * cornerRadius - 4 * cornerRadius - 2 * lineWidth)
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(style: StrokeStyle(lineWidth: lineWidth,
                                                             lineCap: .round,
                                                             lineJoin: .round,
                                                             dash: [dash, perimeter - dash],
                                                             dashPhase: (update ? 1 : -1) * (perimeter / 2)))
                            .foregroundStyle(
                                LinearGradient(gradient: Gradient(colors: [.green, .red]),
                                               startPoint: .trailing,
                                               endPoint: .leading)
                            )
                            .shadow(radius: 2)
                    }
                    .onAppear {
                        update = false
                        withAnimation(.linear.speed(0.1).repeatForever(autoreverses: false)) {
                            update.toggle()
                        }
                    }
                }
            }
    }
}
