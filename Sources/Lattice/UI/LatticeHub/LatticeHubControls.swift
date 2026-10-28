// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct HubControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : Color.primary.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? tint : (isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)))
                }
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { isHovered = $0 }
    }
}

struct HubQuickControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var keepAwake = KeepAwakeManager.shared
    @ObservedObject private var toggles = QuickTogglesService.shared
    @Environment(\.colorScheme) private var colorScheme
    let onDismiss: () -> Void

    private var strings: QuickToggleFeatureStrings {
        FeatureStrings.quickToggles(l10n.language)
    }

    var body: some View {
        HStack(spacing: 6) {
            HubControlButton(icon: micMute.isMuted ? "mic.slash.fill" : "mic.fill",
                             title: micMute.isMuted ? l10n.s.micUnmuteName : l10n.s.micMuteName,
                             isActive: micMute.isMuted,
                             tint: .red) {
                micMute.toggle()
            }
            HubControlButton(icon: keepAwake.isActive ? "bolt.fill" : "bolt",
                             title: l10n.s.keepAwakeTitle,
                             isActive: keepAwake.isActive,
                             tint: .orange) {
                keepAwake.toggle()
            }
            HubControlButton(icon: colorScheme == .dark ? "moon.fill" : "sun.max.fill",
                             title: colorScheme == .dark ? strings.darkModeToLight : strings.darkModeToDark,
                             isActive: colorScheme == .dark,
                             tint: .indigo) {
                toggles.toggleDarkMode()
            }
            HubControlButton(icon: toggles.hiddenFilesShown ? "eye.fill" : "eye.slash.fill",
                             title: toggles.hiddenFilesShown ? strings.hiddenFilesHide : strings.hiddenFilesShow,
                             isActive: toggles.hiddenFilesShown,
                             tint: .blue) {
                toggles.toggleHiddenFiles()
            }
            HubControlButton(icon: toggles.desktopIconsShown ? "macwindow" : "macwindow.slash",
                             title: toggles.desktopIconsShown ? strings.desktopIconsHide : strings.desktopIconsShow,
                             isActive: toggles.desktopIconsShown,
                             tint: .teal) {
                toggles.toggleDesktopIcons()
            }
            HubControlButton(icon: "trash",
                             title: strings.emptyTrashTitle,
                             isActive: false,
                             tint: .gray) {
                onDismiss()
                toggles.emptyTrash()
            }
            HubControlButton(icon: "lock.fill",
                             title: strings.lockScreenTitle,
                             isActive: false,
                             tint: .secondary) {
                onDismiss()
                toggles.lockScreen()
            }
        }
        .padding(.horizontal, 2)
    }
}
