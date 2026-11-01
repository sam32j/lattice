// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubView {
    var islandRailRows: Int {
        let geometry = NotchService.shared.expandedGeometry
        let budget = launcher.visibleItems.count >= NotchLayout.toolTwoRowThreshold ? geometry.pageBudget : geometry.contentBudget
        return NotchLayout.toolRailRows(count: launcher.visibleItems.count, width: notchSize?.width ?? 420,
            height: max(0, budget - launcher.notchControlsHeight - 6))
    }

    var islandMainHeight: CGFloat {
        let controls = launcher.notchControlsHeight
        let rail = launcher.visibleItems.isEmpty ? NotchLayout.hubEmptyHeight : NotchLayout.railHeight(
            rows: islandRailRows, rowHeight: NotchLayout.toolHeight, spacing: NotchLayout.toolSpacing)
        return controls + rail + (controls > 0 ? 6 : 0)
    }

    @ViewBuilder var grid: some View {
        if let notchSize {
            let items = launcher.visibleItems
            let rows = islandRailRows
            let columns = NotchLayout.railColumns(count: items.count, rows: rows)
            let horizontal = NotchLayout.railGap(columns: columns, itemWidth: NotchLayout.toolWidth,
                spacing: NotchLayout.toolSpacing, least: NotchLayout.toolLeastSpacing, width: notchSize.width) != nil
            NotchRail(items: items, rows: rows, itemWidth: NotchLayout.toolWidth, width: notchSize.width,
                      spacing: NotchLayout.toolSpacing, leastSpacing: NotchLayout.toolLeastSpacing,
                      rowSpacing: NotchLayout.toolSpacing, rowAlignment: .leading,
                      scrollTarget: launcher.keyboardIndex.flatMap { items.indices.contains($0) ? items[$0].id : nil }) { item in
                draggableCell(item, horizontal: horizontal).frame(height: NotchLayout.toolHeight)
            }
            .frame(height: NotchLayout.railHeight(rows: rows, rowHeight: NotchLayout.toolHeight,
                                                 spacing: NotchLayout.toolSpacing))
            .background { HubDragView(destination: .scrollRegion, session: dragSession, isEnabled: launcher.isEditing) }
        } else {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(launcher.visibleItems) { item in draggableCell(item, horizontal: true) }
            }
        }
    }

    private func draggableCell(_ item: LatticeHubItem, horizontal: Bool) -> some View {
        cell(item)
            .modifier(HubDragModifier(item: .tool(item), session: dragSession, isEnabled: launcher.isEditing,
                horizontal: horizontal, symbol: icon(for: item), onClick: { handleToolTap(item) }))
            .transaction(value: launcher.isEditing) { $0.animation = nil }
    }

    private func handleToolTap(_ item: LatticeHubItem) {
        if launcher.isEditing {
            if hasQuickOptions(item) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    launcher.editingOptionsItem = launcher.editingOptionsItem == item ? nil : item
                }
            }
        } else { launcher.run(item) }
    }

    func cell(_ item: LatticeHubItem, titleInset: CGFloat = 0) -> some View {
        let index = launcher.visibleItems.firstIndex(of: item)
        let showsFocus = notchSize != nil ? NotchService.shared.showsKeyboardFocus : launcher.keyboardIndex != nil
        let isSelected = !launcher.isEditing && showsFocus && index != nil && index == launcher.selectedIndex
        let isHovered = hoveredItem == item

        let tileContent = Group {
            if notchSize != nil {
                Image(systemName: icon(for: item))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(iconColor(item))
                    .frame(height: NotchLayout.toolHeight)
            } else {
                VStack(spacing: 5) {
                    Image(systemName: icon(for: item))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(iconColor(item))
                        .frame(height: 24)
                    Text(title(for: item))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .padding(.horizontal, titleInset)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: notchSize == nil ? 64 : NotchLayout.toolHeight)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        }

        return Button { handleToolTap(item) } label: { tileContent }
            .buttonStyle(.plain)
            .contextMenu {
                if launcher.isEditing {
                    Button(customizationText.hideFromHub) { launcher.setHidden(item, true) }
                } else {
                    Button(customizationText.manageTools + "…") { launcher.isEditing = true }
                }
            }
            .help(launcher.isEditing ? customizationText.dragHint : title(for: item))
            .accessibilityLabel(title(for: item))
            .onHover { hovering in
                guard dragSession.active == nil else { return }
                if hovering {
                    if hoveredItem != item { hoveredItem = item }
                    if !launcher.isEditing, launcher.keyboardIndex != nil { launcher.keyboardIndex = nil }
                } else if hoveredItem == item { hoveredItem = nil }
            }
    }
}
