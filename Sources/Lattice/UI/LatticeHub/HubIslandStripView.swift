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
                                        .frame(width: pageIndex == layout.pages - 1 ? notchWidth : layout.pageStride,
                                               height: layout.size.height)
                                        .id("hub_island_page_\(pageIndex)")
                                }
                            }
                            .scrollTargetLayout()
                            surface
                        }
                    }
                    .scrollIndicators(.never)
                    .scrollDisabled(session.active != nil)
                    .scrollTargetBehavior(HubIslandPagingBehavior(pageStride: layout.pageStride))
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

private struct HubIslandPagingBehavior: ScrollTargetBehavior {
    let pageStride: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let stride = max(1, pageStride)
        let maxScroll = max(0, context.contentSize.width - context.containerSize.width)
        guard maxScroll > 0 else { return }

        let startX = context.originalTarget.rect.origin.x
        let proposedX = target.rect.origin.x
        let delta = proposedX - startX

        let currentPage = round(startX / stride)
        let targetPage: CGFloat

        if context.velocity.dx > 12 {
            targetPage = min(currentPage + 1, ceil(maxScroll / stride))
        } else if context.velocity.dx < -12 {
            targetPage = max(currentPage - 1, 0)
        } else if abs(delta) >= 100 {
            if delta > 0 {
                targetPage = min(currentPage + 1, ceil(maxScroll / stride))
            } else {
                targetPage = max(currentPage - 1, 0)
            }
        } else {
            targetPage = currentPage
        }

        let snappedX = max(0, min(targetPage * stride, maxScroll))
        target.rect.origin.x = snappedX
    }
}
