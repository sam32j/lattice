// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubView {
    var hiddenTray: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dragSession.active != nil ? customizationText.dropToHide : customizationText.availableTools)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(dragSession.active != nil ? Color.accentColor : Color.secondary)
                .lineLimit(1)
                .frame(height: 12, alignment: .leading)
            if launcher.hiddenControls.isEmpty && launcher.hiddenItems.isEmpty {
                Label(customizationText.dragToHide, systemImage: "arrow.down.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(trayOutline)
            } else if notchSize != nil {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) { hiddenButtons }
                        .padding(.horizontal, 6)
                        .frame(height: 36)
                }
                .scrollIndicators(.hidden)
                .frame(height: 36)
                .background(trayOutline)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityIdentifier("hub-available-tools-scroll")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) { hiddenButtons }
                    .padding(6)
                    .background(trayOutline)
            }
        }
        .overlay {
            HubDragView(destination: .hiddenTray, session: dragSession, isEnabled: launcher.isEditing)
        }
        .accessibilityIdentifier("hub-available-tools")
    }

    private var trayOutline: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(dragSession.active != nil ? Color.accentColor.opacity(dragSession.targetsHiddenTray ? 1 : 0.55) : Color.primary.opacity(0.12),
                style: StrokeStyle(lineWidth: dragSession.targetsHiddenTray ? 1.5 : 1,
                                   dash: dragSession.active != nil ? [4, 4] : []))
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(dragSession.targetsHiddenTray ? Color.accentColor.opacity(0.08) : Color.clear))
    }

    @ViewBuilder private var hiddenButtons: some View {
        ForEach(launcher.hiddenControls) { control in
            restoreButton(control.title(l10n: l10n, colorScheme: colorScheme)) {
                launcher.setControlHidden(control, false)
            }
        }
        ForEach(launcher.hiddenItems) { item in
            restoreButton(title(for: item)) { launcher.setHidden(item, false) }
        }
    }

    private func restoreButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill")
                .font(.system(size: 10.5, weight: .medium))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(minWidth: 100, maxWidth: notchSize == nil ? .infinity : nil, alignment: .leading)
                .frame(height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
