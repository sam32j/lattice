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
            Text(strings.previewPositionAutomatic).tag(ScreenshotSupport.QuickPreviewPosition.automatic.rawValue)
            Text(strings.previewPositionTopLeft).tag(ScreenshotSupport.QuickPreviewPosition.topLeft.rawValue)
            Text(strings.previewPositionTopRight).tag(ScreenshotSupport.QuickPreviewPosition.topRight.rawValue)
            Text(strings.previewPositionBottomLeft).tag(ScreenshotSupport.QuickPreviewPosition.bottomLeft.rawValue)
            Text(strings.previewPositionBottomRight).tag(ScreenshotSupport.QuickPreviewPosition.bottomRight.rawValue)
        }
    }
}
