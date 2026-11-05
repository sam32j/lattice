// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Exclusive Dynamic Island widget section showing at most three tiles:
/// Now Playing, Calendar, and Timer, each with tinted icon and no text label.
struct HubIslandWidgetSection: View {
    @ObservedObject private var service = NotchService.shared
    @ObservedObject private var l10n = L10n.shared
    let isEditing: Bool

    struct WidgetItem: Identifiable {
        let id: NotchModule
        let symbol: String
        let tint: Color
        let title: String
    }

    private var items: [WidgetItem] {
        var result: [WidgetItem] = []
        if service.modules.contains(.music) {
            result.append(WidgetItem(
                id: .music,
                symbol: "waveform.mid",
                tint: .pink,
                title: "Now Playing"
            ))
        }
        if service.modules.contains(.calendar) {
            result.append(WidgetItem(
                id: .calendar,
                symbol: "calendar",
                tint: Color(red: 1, green: 0.36, blue: 0.39),
                title: NotchModule.calendar.title(l10n.language)
            ))
        }
        if service.modules.contains(.timer) {
            result.append(WidgetItem(
                id: .timer,
                symbol: "timer",
                tint: .orange,
                title: NotchModule.timer.title(l10n.language)
            ))
        }
        return result
    }

    var body: some View {
        let widgets = items
        if !widgets.isEmpty {
            HStack(spacing: 6) {
                ForEach(widgets) { item in
                    HubIslandWidgetTile(item: item, isEditing: isEditing) {
                        guard !isEditing else { return }
                        NotchService.shared.open(item.id)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.hubWidgetTileHeight)
        }
    }
}

struct HubIslandWidgetTile: View {
    let item: HubIslandWidgetSection.WidgetItem
    let isEditing: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered && !isEditing ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                Image(systemName: item.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(item.tint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.hubWidgetTileHeight)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(item.title)
        .accessibilityLabel(item.title)
        .onHover { hovering in
            if isHovered != hovering { isHovered = hovering }
        }
    }
}
