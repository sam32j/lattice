// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Paging and live slot feedback share the native session used by the hide
/// tray. Only a changed destination index updates SwiftUI while dragging.
struct HubIslandStripView<Content: View>: View {
    let items: [LatticeHubItem]
    let notchWidth: CGFloat
    let columns: Int
    let isEditing: Bool
    @ObservedObject var launcher: LatticeHubService
    @ObservedObject var session: HubDragSession
    let onTap: (LatticeHubItem) -> Void
    @ViewBuilder let cellContent: (LatticeHubItem) -> Content
    private var layout: HubToolLayout { .island(count: items.count, width: notchWidth, columns: columns) }

    var body: some View {
        Group {
            if layout.isPaged {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            HStack(spacing: 0) {
                                ForEach(0..<layout.pages, id: \.self) { pageIndex in
                                    Color.clear
                                        .frame(width: layout.pageStride, height: 1)
                                        .id("hub_island_page_\(pageIndex)")
                                }
                            }
                            surface
                        }
                    }
                    .scrollIndicators(.never)
                    .scrollDisabled(session.active != nil)
                    .scrollTargetBehavior(HubStripScrollTargetBehavior(isDragging: session.active != nil, stride: layout.pageStride))
                    .onChange(of: launcher.selectedIndex) { _, newIndex in
                        guard let newIndex, items.indices.contains(newIndex) else { return }
                        let capacity = max(1, columns * 2)
                        let targetPage = min(max(0, newIndex / capacity), max(0, layout.pages - 1))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("hub_island_page_\(targetPage)", anchor: .leading)
                        }
                    }
                    .onChange(of: launcher.presentationID) { _, _ in
                        proxy.scrollTo("hub_island_page_0", anchor: .leading)
                    }
                }
            } else { surface }
        }
        .frame(width: notchWidth, height: layout.size.height, alignment: .leading)
        .onDisappear { session.cancel() }
        .onChange(of: isEditing) { _, editing in if !editing { session.cancel() } }
    }

    private var surface: some View {
        HubToolSurface(items: items, layout: layout, isEditing: isEditing,
            session: session, onTap: onTap, onManage: { launcher.isEditing = true }, cellContent: cellContent)
    }
}
