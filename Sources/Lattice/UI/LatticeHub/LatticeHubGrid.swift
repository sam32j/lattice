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

        return HubToolCellView(
            item: item,
            isNotch: notchSize != nil,
            isEditing: launcher.isEditing,
            isSelected: isSelected,
            titleInset: titleInset,
            isDragging: dragSession.active != nil,
            onTap: { handleToolTap(item) },
            onManage: { launcher.isEditing = true },
            onHide: { launcher.setHidden(item, true) },
            iconName: icon(for: item),
            itemTitle: title(for: item),
            iconColor: iconColor(item)
        )
    }
}

struct HubToolCellView: View {
    let item: LatticeHubItem
    let isNotch: Bool
    let isEditing: Bool
    let isSelected: Bool
    let titleInset: CGFloat
    let isDragging: Bool
    let onTap: () -> Void
    let onManage: () -> Void
    let onHide: () -> Void
    let iconName: String
    let itemTitle: String
    let iconColor: Color

    @State private var isHovered = false
    @ObservedObject private var l10n = L10n.shared

    private var customizationText: HubCustomizationStrings { FeatureStrings.hubCustomization(l10n.language) }

    var body: some View {
        let tileContent = Group {
            if isNotch {
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(height: NotchLayout.toolHeight)
            } else {
                VStack(spacing: 5) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(height: 24)
                    Text(itemTitle)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .padding(.horizontal, titleInset)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isNotch ? NotchLayout.toolHeight : 64)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        }

        return Button(action: onTap) { tileContent }
            .buttonStyle(.plain)
            .contextMenu {
                if isEditing {
                    Button(customizationText.hideFromHub) { onHide() }
                } else {
                    Button(customizationText.manageTools + "…") { onManage() }
                }
            }
            .help(isEditing ? customizationText.dragHint : itemTitle)
            .accessibilityLabel(itemTitle)
            .onHover { hovering in
                guard !isDragging else {
                    if isHovered { isHovered = false }
                    return
                }
                if isHovered != hovering { isHovered = hovering }
                if hovering, !isEditing, LatticeHubService.shared.keyboardIndex != nil {
                    LatticeHubService.shared.keyboardIndex = nil
                }
            }
    }
}
