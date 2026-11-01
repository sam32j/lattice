// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Items fill each column top to bottom and continue sideways, so a short
/// island scrolls to the side and never down. Whenever everything fits
/// without scrolling, the items read left to right instead, in rows of equal
/// cells across the full width, and a short last row sits centered. A rail
/// given `leastSpacing` closes its gaps toward it before it scrolls.
struct NotchRail<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let rows: Int
    let itemWidth: CGFloat
    let width: CGFloat
    var spacing: CGFloat = 8
    var leastSpacing: CGFloat? = nil
    var rowSpacing: CGFloat = 8
    var rowAlignment: HorizontalAlignment = .center
    var scrollTarget: Item.ID? = nil
    @ViewBuilder let content: (Item) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: Int { NotchLayout.railColumns(count: items.count, rows: rows) }
    private var starts: [Int] { Array(stride(from: 0, to: items.count, by: max(1, rows))) }
    private var rowStarts: [Int] { Array(stride(from: 0, to: items.count, by: max(1, columns))) }
    /// Nil while the rail scrolls.
    private var gap: CGFloat? {
        NotchLayout.railGap(columns: columns, itemWidth: itemWidth, spacing: spacing,
                            least: leastSpacing ?? spacing, width: width)
    }

    // Scroll to the column itself: its identity is known before lazy children
    // are created, including a target well outside the current viewport.
    private var targetColumn: Int? {
        guard let scrollTarget, let index = items.firstIndex(where: { $0.id == scrollTarget }) else { return nil }
        return index / max(1, rows) * max(1, rows)
    }

    var body: some View {
        if let gap {
            let capacity = NotchLayout.railCapacity(width: width, itemWidth: itemWidth, spacing: spacing)
            let maxCell = (width - CGFloat(max(0, capacity - 1)) * gap) / CGFloat(max(1, capacity))
            let rawCell = (width - CGFloat(max(0, columns - 1)) * gap) / CGFloat(max(1, columns))
            let cell = min(rawCell, max(maxCell, itemWidth))
            VStack(spacing: rowSpacing) {
                ForEach(rowStarts, id: \.self) { start in row(start, cell: cell, gap: gap) }
            }
        } else {
            ScrollViewReader { proxy in
                // Legacy scroll bars would take a row's worth of height; the
                // column cut at the edge is the cue that more follows.
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        ForEach(starts, id: \.self) { start in column(start).frame(width: itemWidth).id(start) }
                    }
                    .contentShape(Rectangle())
                }
                .scrollIndicators(.never)
                .notchScrollEdgeFade(.horizontal)
                .onAppear {
                    if let targetColumn { proxy.scrollTo(targetColumn, anchor: .center) }
                }
                .onChange(of: targetColumn) { _, target in
                    guard let target else { return }
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    private func row(_ start: Int, cell: CGFloat, gap: CGFloat) -> some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(items[start..<min(items.count, start + max(1, columns))]) { item in
                content(item).frame(width: cell)
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: rowAlignment, vertical: .top))
    }

    private func column(_ start: Int) -> some View {
        VStack(spacing: rowSpacing) {
            ForEach(items[start..<min(items.count, start + max(1, rows))]) { item in
                content(item)
            }
        }
    }
}

