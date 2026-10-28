// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubView {
    @ViewBuilder var grid: some View {
        if let notchSize, !launcher.isEditing {
            let controlsH = launcher.activeUtility == nil ? launcher.notchControlsHeight : 0
            let vstackSpacing: CGFloat = controlsH > 0 ? 6 : 0
            let availableHeight = max(0, notchSize.height - controlsH - vstackSpacing)
            let rows = NotchLayout.railRows(count: launcher.visibleItems.count,
                                            perRow: NotchLayout.railCapacity(width: notchSize.width, itemWidth: NotchLayout.toolWidth,
                                                                             spacing: NotchLayout.toolSpacing),
                                            rowHeight: NotchLayout.toolHeight, spacing: NotchLayout.toolSpacing, height: availableHeight)
            let titleInset = NotchLayout.toolTitleInset(count: launcher.visibleItems.count, rows: rows, width: notchSize.width)
            NotchRail(items: launcher.visibleItems, rows: rows, itemWidth: NotchLayout.toolWidth, width: notchSize.width,
                      spacing: NotchLayout.toolSpacing, leastSpacing: NotchLayout.toolLeastSpacing,
                      rowSpacing: NotchLayout.toolSpacing,
                      scrollTarget: launcher.keyboardIndex.flatMap { index in
                          launcher.visibleItems.indices.contains(index) ? launcher.visibleItems[index].id : nil
                      }) { item in
                cell(item, titleInset: titleInset).frame(height: NotchLayout.toolHeight)
            }
        } else {
            LazyVGrid(columns: columns, spacing: notchSize == nil ? 10 : 6) {
                ForEach(launcher.visibleItems) { item in
                    PanelReorderableItem(item: item,
                                         isEnabled: launcher.isEditing,
                                         order: launcher.itemOrderBinding,
                                         dragging: $draggingItem) {
                        cell(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func cell(_ item: LatticeHubItem, titleInset: CGFloat = 0) -> some View {
        let index = launcher.visibleItems.firstIndex(of: item)
        let isSelected = !launcher.isEditing && index != nil && index == launcher.selectedIndex
        let isHovered = hoveredItem == item

        Button {
            if launcher.isEditing {
                if hasQuickOptions(item) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        launcher.editingOptionsItem = launcher.editingOptionsItem == item ? nil : item
                    }
                }
            } else {
                launcher.run(item)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
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

                if launcher.isEditing {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { launcher.setHidden(item, true) }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                hoveredItem = item
                launcher.select(item)
            } else if hoveredItem == item {
                hoveredItem = nil
            }
        }
    }
}
