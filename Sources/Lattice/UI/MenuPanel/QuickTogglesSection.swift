// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The quick toggles tab of the menu panel: one-click system actions, each an
/// action row that can be hidden and reordered in the section's edit mode.
struct QuickTogglesSection: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var draggingItem: QuickToggleAction?
    var collapsible = true
    var notchSize: CGSize? = nil

    private var shouldShowHubButton: Bool {
        notchSize == nil && AppFeature.quickLauncher.isAvailable
    }

    var body: some View {
        PanelSection(.toggles,
                     title: FeatureStrings.quickToggles(l10n.language).pageTitle,
                     collapsible: collapsible,
                     supportsEditing: true,
                     resetAction: QuickTogglesList.resetPanelDefaults) { editing in
            VStack(spacing: 8) {
                if !editing, shouldShowHubButton {
                    hubBridgeButton
                }
                QuickTogglesList(editing: editing, draggingItem: $draggingItem) {
                    appDelegate()?.closePopover()
                }
            }
            // Actions here activate other apps (the Finder restarting, System
            // Events, the Trash confirmation), which would dismiss the panel
            // mid-flow; holding it open keeps a toggle-back one click away.
            // The status icon and switching tabs still close as always.
            .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
            .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
        }
    }

    private var hubBridgeButton: some View {
        Button {
            let anchor = appDelegate()?.statusItemFrame
            appDelegate()?.closePopover()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                LatticeHubService.shared.show(anchoredBelow: anchor)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(l10n.s.launcherName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                if GlobalShortcutRole.quickLauncher.savedShortcut.isValid {
                    Text(GlobalShortcutRole.quickLauncher.savedShortcut.displayString)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .buttonStyle(.plain)
        .help(UtilitySettingsCopy.open(l10n.s.launcherName, l10n.language))
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func shortcutHint(_ role: GlobalShortcutRole) -> String? {
        guard role.savedShortcut.isValid,
              role.requiredEnableKeys.allSatisfy({ UserDefaults.standard.bool(forKey: $0) })
        else { return nil }
        return role.savedShortcut.displayString
    }
}
