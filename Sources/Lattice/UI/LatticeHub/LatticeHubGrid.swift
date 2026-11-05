// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubView {
    var islandRailRows: Int {
        HubStripLayout.rows(for: launcher.visibleItems.count, columns: NotchService.shared.expandedGeometry.hubColumns)
    }

    var islandMainHeight: CGFloat {
        NotchService.shared.expandedGeometry.hubContentHeight(toolCount: launcher.visibleItems.count,
            controlsHeight: launcher.notchControlsHeight, editing: false)
    }

    @ViewBuilder var grid: some View {
        if let notchSize {
            HubIslandStripView(items: launcher.visibleItems,
                               notchWidth: notchSize.width,
                               columns: NotchService.shared.expandedGeometry.hubColumns,
                               isEditing: launcher.isEditing,
                               launcher: launcher,
                               session: dragSession,
                               onTap: { handleToolTap($0) }) { item in
                cell(item)
            }
            .frame(height: NotchLayout.railHeight(rows: islandRailRows,
                                                 rowHeight: NotchLayout.toolHeight,
                                                 spacing: NotchLayout.toolSpacing))
        } else {
            HubFloatingToolGrid(items: launcher.visibleItems, isEditing: launcher.isEditing,
                session: dragSession, onTap: handleToolTap, onManage: { launcher.isEditing = true }) { item in
                cell(item)
            }
        }
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
        let showsFocus = launcher.keyboardIndex != nil
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
