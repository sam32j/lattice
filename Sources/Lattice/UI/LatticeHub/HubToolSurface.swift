// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// One renderer for the HUD grid and island rail. Native receivers stay fixed
/// while intervening tiles move to open the exact slot used on drop.
struct HubToolSurface<Content: View>: View {
    let items: [LatticeHubItem]
    let layout: HubToolLayout
    let isEditing: Bool
    @ObservedObject var session: HubDragSession
    let onTap: (LatticeHubItem) -> Void
    let onManage: () -> Void
    @ViewBuilder let cellContent: (LatticeHubItem) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sourceIndex: Int? {
        guard case .tool(let item) = session.active else { return nil }
        return items.firstIndex(of: item)
    }

    private var insertionIndex: Int? {
        guard let index = session.targetIndex, layout.frames.indices.contains(index) else { return nil }
        return index
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let preview = HubStripLayout.previewIndex(for: index,
                    draggingFrom: sourceIndex, targetIndex: insertionIndex)
                let frame = layout.frames[preview]
                cellContent(item)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.14), value: preview)
                    .opacity(session.active == .tool(item) ? 0 : 1)
                    .highPriorityGesture(LongPressGesture(minimumDuration: 2.0).onEnded { _ in
                        if !isEditing {
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            onManage()
                        }
                    })
            }
            if sourceIndex != nil, let target = insertionIndex, !session.targetsHiddenTray {
                let frame = layout.frames[target]
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .overlay {
            HubDragView(destination: .tools, session: session, isEnabled: isEditing,
                        toolItems: items, toolLayout: layout, onToolTap: onTap)
        }
        .onDisappear { session.cancel() }
        .onChange(of: items) { _, _ in session.cancel() }
        .onChange(of: isEditing) { _, editing in if !editing { session.cancel() } }
    }
}

struct HubFloatingToolGrid<Content: View>: View {
    let items: [LatticeHubItem]
    let isEditing: Bool
    @ObservedObject var session: HubDragSession
    let onTap: (LatticeHubItem) -> Void
    let onManage: () -> Void
    @ViewBuilder let cellContent: (LatticeHubItem) -> Content

    var body: some View {
        GeometryReader { proxy in
            HubToolSurface(items: items, layout: .hud(count: items.count, width: proxy.size.width),
                isEditing: isEditing, session: session, onTap: onTap, onManage: onManage, cellContent: cellContent)
        }
        .frame(height: HubToolLayout.hudHeight(count: items.count))
    }
}
