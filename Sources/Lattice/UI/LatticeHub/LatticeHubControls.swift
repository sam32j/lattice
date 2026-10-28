// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

enum HubControlAction: String, CaseIterable, Identifiable, PanelOrderItem {
    case micMute, keepAwake, darkMode, keyboardLight, hiddenFiles, desktopIcons
    case emptyTrash, ejectDisks, lockScreen, displayOff, screenSaver

    var id: String { rawValue }

    var isAvailable: Bool {
        switch self {
        case .micMute: return AppFeature.micMute.isAvailable
        case .keepAwake: return AppFeature.keepAwake.isAvailable
        case .darkMode, .displayOff: return AppFeature.brightness.isAvailable
        case .keyboardLight:
            return AppFeature.brightness.isAvailable && BrightnessService.shared.keyboardLightEnabled != nil
        case .hiddenFiles, .desktopIcons, .emptyTrash, .ejectDisks, .lockScreen, .screenSaver:
            return AppFeature.commandBar.isAvailable
        }
    }

    func title(l10n: L10n, colorScheme: ColorScheme) -> String {
        let strings = FeatureStrings.quickToggles(l10n.language)
        switch self {
        case .micMute: return MicMuteService.shared.isMuted ? l10n.s.micUnmuteName : l10n.s.micMuteName
        case .keepAwake: return l10n.s.keepAwakeTitle
        case .darkMode: return colorScheme == .dark ? strings.darkModeToLight : strings.darkModeToDark
        case .keyboardLight: return FeatureStrings.brightness(l10n.language).keyboardLight
        case .hiddenFiles: return QuickTogglesService.shared.hiddenFilesShown ? strings.hiddenFilesHide : strings.hiddenFilesShow
        case .desktopIcons: return QuickTogglesService.shared.desktopIconsShown ? strings.desktopIconsHide : strings.desktopIconsShow
        case .emptyTrash: return strings.emptyTrashTitle
        case .ejectDisks: return strings.ejectTitle
        case .lockScreen: return strings.lockScreenTitle
        case .displayOff: return strings.displayOffTitle
        case .screenSaver: return strings.screenSaverTitle
        }
    }

    func icon(colorScheme: ColorScheme) -> String {
        switch self {
        case .micMute: return MicMuteService.shared.isMuted ? "mic.slash.fill" : "mic.fill"
        case .keepAwake: return KeepAwakeManager.shared.isActive ? "bolt.fill" : "bolt"
        case .darkMode: return colorScheme == .dark ? "moon.fill" : "sun.max.fill"
        case .keyboardLight: return (BrightnessService.shared.keyboardLightEnabled ?? false) ? "keyboard.fill" : "keyboard"
        case .hiddenFiles: return QuickTogglesService.shared.hiddenFilesShown ? "eye.fill" : "eye.slash.fill"
        case .desktopIcons: return QuickTogglesService.shared.desktopIconsShown ? "macwindow" : "macwindow.slash"
        case .emptyTrash: return "trash"
        case .ejectDisks: return "eject.fill"
        case .lockScreen: return "lock.fill"
        case .displayOff: return "display"
        case .screenSaver: return "sparkles.tv"
        }
    }

    func isActive(colorScheme: ColorScheme) -> Bool {
        switch self {
        case .micMute: return MicMuteService.shared.isMuted
        case .keepAwake: return KeepAwakeManager.shared.isActive
        case .darkMode: return colorScheme == .dark
        case .keyboardLight: return BrightnessService.shared.keyboardLightEnabled ?? false
        case .hiddenFiles: return QuickTogglesService.shared.hiddenFilesShown
        case .desktopIcons: return QuickTogglesService.shared.desktopIconsShown
        case .emptyTrash, .ejectDisks, .lockScreen, .displayOff, .screenSaver: return false
        }
    }

    var tint: Color {
        switch self {
        case .micMute: return .red
        case .keepAwake: return .orange
        case .darkMode: return .indigo
        case .keyboardLight: return .purple
        case .hiddenFiles: return .blue
        case .desktopIcons: return .teal
        case .emptyTrash: return .gray
        case .ejectDisks: return .brown
        case .lockScreen, .displayOff, .screenSaver: return .secondary
        }
    }

    func run(onDismiss: @escaping () -> Void) {
        let toggles = QuickTogglesService.shared
        switch self {
        case .micMute: MicMuteService.shared.toggle()
        case .keepAwake: KeepAwakeManager.shared.toggle()
        case .darkMode: toggles.toggleDarkMode()
        case .keyboardLight:
            let brightness = BrightnessService.shared
            brightness.setKeyboardLightEnabled(!(brightness.keyboardLightEnabled ?? false))
        case .hiddenFiles: toggles.toggleHiddenFiles()
        case .desktopIcons: toggles.toggleDesktopIcons()
        case .emptyTrash: onDismiss(); toggles.emptyTrash()
        case .ejectDisks: toggles.ejectAllDisks()
        case .lockScreen: onDismiss(); toggles.lockScreen()
        case .displayOff: onDismiss(); toggles.turnDisplayOff()
        case .screenSaver: onDismiss(); toggles.startScreenSaver()
        }
    }
}

struct HubControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var tint: Color = .accentColor
    var height: CGFloat = 28
    var iconSize: CGFloat = 13
    var isEditing: Bool = false
    var onHide: (() -> Void)? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: { if !isEditing { action() } }) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(isActive ? .white : Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background {
                        RoundedRectangle(cornerRadius: max(6, height * 0.28), style: .continuous)
                            .fill(isActive ? tint : (isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)))
                    }
            }
            .buttonStyle(.plain)
            .help(title)
            .accessibilityLabel(title)
            .onHover { isHovered = $0 }

            if isEditing, let onHide {
                Button(action: onHide) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: max(10, iconSize), weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.red)
                }
                .buttonStyle(.plain)
                .offset(x: 3, y: -3)
            }
        }
    }
}

struct HubQuickControls: View {
    var notchSize: CGSize? = nil
    var isEditing: Bool = false
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var launcher = LatticeHubService.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var keepAwake = KeepAwakeManager.shared
    @ObservedObject private var toggles = QuickTogglesService.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @Environment(\.colorScheme) private var colorScheme
    let onDismiss: () -> Void

    private var isNotch: Bool { notchSize != nil }

    var body: some View {
        let controls = launcher.visibleControls
        if !controls.isEmpty {
            HStack(spacing: isNotch ? 4 : 5) {
                ForEach(controls) { action in
                    HubControlButton(icon: action.icon(colorScheme: colorScheme),
                                     title: action.title(l10n: l10n, colorScheme: colorScheme),
                                     isActive: action.isActive(colorScheme: colorScheme),
                                     tint: action.tint,
                                     height: isNotch ? 24 : 28,
                                     iconSize: isNotch ? 11 : 13,
                                     isEditing: isEditing,
                                     onHide: {
                                         withAnimation(.easeOut(duration: 0.15)) {
                                             launcher.setControlHidden(action, true)
                                         }
                                     }) {
                        action.run(onDismiss: onDismiss)
                    }
                }
            }
            .padding(.horizontal, isNotch ? 0 : 2)
        }
    }
}
