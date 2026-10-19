// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct WallpaperSettings: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        SettingsCard(title: FeatureStrings.wallpaper(l10n.language).pageTitle) {
            Toggle(FeatureStrings.wallpaper(l10n.language).applyAllDisplays,
                   isOn: Binding(
                    get: { WallpaperService.shared.applyAllDisplays },
                    set: { WallpaperService.shared.applyAllDisplays = $0 }
                   ))
            Button {
                WallpaperService.shared.openSystemWallpaperSettings()
            } label: {
                Label(FeatureStrings.wallpaper(l10n.language).openSystemSettings,
                      systemImage: "gearshape")
            }
        }
    }
}
