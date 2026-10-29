// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct IslandDestinationSettings: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let destination: IslandDestination
    var includeDivider = false
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchClipboardWindow) private var clipboardRoute = true
    @AppStorage(DefaultsKey.notchShelf) private var fileRoute = true
    @AppStorage(DefaultsKey.notchScratchpad) private var scratchpadRoute = true
    @AppStorage(DefaultsKey.notchCameraEnabled) private var cameraRoute = true
    @AppStorage(DefaultsKey.notchQuickPanel) private var launcherRoute = true
    @AppStorage(DefaultsKey.notchVideoDownloader) private var videoDownloaderRoute = true
    @AppStorage(DefaultsKey.notchDragReveal) private var dragReveal = true
    @AppStorage(DefaultsKey.notchClipboardCardSize) private var cardSize = NotchClipboardCardSize.comfortable.rawValue

    private var shown: Binding<Bool> {
        _ = hidden
        _ = clipboardRoute
        _ = fileRoute
        _ = scratchpadRoute
        _ = cameraRoute
        _ = launcherRoute
        _ = videoDownloaderRoute
        return Binding(get: { destination.isShown(in: .standard) }, set: { shown in
            withAnimation(reduceMotion ? nil : .settingsExpansion) {
                destination.setShown(shown, in: .standard)
                sync()
            }
        })
    }

    var body: some View {
        if islandEnabled && features.isAvailable(.notch) {
            VStack(alignment: .leading, spacing: 13) {
            if includeDivider { Divider() }
            SettingsToggleRow(title: SettingsOwnershipStrings.text(.showIsland, l10n.language), isOn: shown)
            if shown.wrappedValue {
                if destination == .files {
                    SettingsToggleRow(title: FeatureStrings.notch(l10n.language).dragReveal, isOn: $dragReveal)
                        .onChange(of: dragReveal) { _, _ in sync() }
                }
                if destination == .clipboard {
                    SettingsControlRow(title: styleTitle) {
                        Picker(styleTitle, selection: $cardSize) {
                            Text(SettingsOwnershipStrings.text(.compact, l10n.language)).tag(NotchClipboardCardSize.compact.rawValue)
                            Text(SettingsOwnershipStrings.text(.regular, l10n.language)).tag(NotchClipboardCardSize.comfortable.rawValue)
                        }.labelsHidden().pickerStyle(.menu)
                    }
                    .onChange(of: cardSize) { _, _ in sync() }
                }
            }
            }
        }
    }

    private var styleTitle: String {
        SettingsOwnershipStrings.text(.displayStyle, l10n.language)
    }

    private func sync() {
        NotchService.shared.syncWithPreferences()
        ShelfService.shared.syncWithPreferences()
        ScratchpadService.shared.syncWithPreferences()
        CameraPreviewService.shared.syncWithPreferences()
        LatticeHubService.shared.syncWithPreferences()
    }
}
