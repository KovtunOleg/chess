//
//  CustomPicker.swift
//  Chess
//
//  Created by Oleg Kovtun on 13.12.2025.
//

import SwiftUI

struct CustomPicker<SelectionValue, ContentView>: View where SelectionValue: Hashable, ContentView: View {
    @Binding var selection: SelectionValue
    let segments: [SelectionValue]
    let segmentView: (SelectionValue) -> ContentView

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.self) { segment in
                Button(action: {
                    withAnimation(.spring()) {
                        selection = segment
                    }
                }) {
                    segmentView(segment)
                        .foregroundColor(selection == segment ? .white : .primary)
                        .background(
                            ZStack {
                                if selection == segment {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue)
                                        .matchedGeometryEffect(id: "segment", in: namespace)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).stroke(.gray, lineWidth: 1))
    }
}
