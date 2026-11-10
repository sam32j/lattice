// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One preference for standalone image and video previews. Island placement
/// remains owned by the island, independent of this corner selection.
struct CapturePreviewPositionPicker: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.screenshotPreviewPosition) private var position = ""

    var body: some View {
        let strings = FeatureStrings.screenshot(l10n.language)
        Picker(strings.previewPositionLabel, selection: $position) {
            Text(CaptureInterfaceStrings.localized(l10n.language).underCursor).tag(ScreenshotSupport.QuickPreviewPosition.automatic.rawValue)
            Text(strings.previewPositionTopLeft).tag(ScreenshotSupport.QuickPreviewPosition.topLeft.rawValue)
            Text(strings.previewPositionTopRight).tag(ScreenshotSupport.QuickPreviewPosition.topRight.rawValue)
            Text(strings.previewPositionBottomLeft).tag(ScreenshotSupport.QuickPreviewPosition.bottomLeft.rawValue)
            Text(strings.previewPositionBottomRight).tag(ScreenshotSupport.QuickPreviewPosition.bottomRight.rawValue)
        }
    }
}

/// Shared display preference for Capture's native / floating presentations.
/// Other preview and history features can reuse CapturePresentationRouting.
struct CapturePresentationPicker: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.capturePresentationDestination) private var destination =
        CapturePresentationRouting.Preference.automatic.rawValue

    var body: some View {
        let copy = CaptureInterfaceStrings.localized(l10n.language)
        Picker(copy.openAt, selection: $destination) {
            Text(copy.automatic).tag(CapturePresentationRouting.Preference.automatic.rawValue)
            Text(copy.dynamicIsland).tag(CapturePresentationRouting.Preference.dynamicIsland.rawValue)
            Text(copy.floatingWindow).tag(CapturePresentationRouting.Preference.floatingWindow.rawValue)
        }
        .pickerStyle(.menu)
    }
}
