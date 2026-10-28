// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubView {
    func title(for item: LatticeHubItem) -> String {
        switch item {
        case .screenshot: return FeatureStrings.screenshot(l10n.language).pageTitle
        case .screenRecorder:
            let strings = FeatureStrings.recorder(l10n.language)
            return recorder.isRecording ? strings.stopButton : strings.pageTitle
        case .cameraPreview: return FeatureStrings.cameraPreview(l10n.language).pageTitle
        case .clipboard: return FeatureStrings.clipboard(l10n.language).title
        case .windowLayout: return FeatureStrings.windowLayout(l10n.language).title
        case .cleaning: return l10n.s.cleaningMenuItem
        case .homebrew: return l10n.s.homebrewName
        case .media: return l10n.s.mediaName
        case .urlCleaner: return l10n.s.urlCleanerName
        case .uninstaller: return l10n.s.uninstallerName
        case .cleaner: return l10n.s.cleanerName
        case .scratchpad: return FeatureStrings.scratchpad(l10n.language).pageTitle
        case .appUpdates: return FeatureStrings.appUpdates(l10n.language).pageTitle
        case .portManager: return FeatureStrings.portManager(l10n.language).title
        }
    }

    func icon(for item: LatticeHubItem) -> String {
        switch item {
        case .screenshot: return "camera.viewfinder"
        case .screenRecorder: return recorder.isRecording ? "stop.circle" : "record.circle"
        case .cameraPreview: return "web.camera"
        case .clipboard: return "doc.on.clipboard"
        case .windowLayout: return "rectangle.3.group"
        case .cleaning: return "keyboard"
        case .homebrew: return "shippingbox"
        case .media: return "photo.on.rectangle.angled"
        case .urlCleaner: return "link"
        case .uninstaller: return "trash"
        case .cleaner: return "sparkle"
        case .scratchpad: return "note.text"
        case .appUpdates: return "arrow.down.app"
        case .portManager: return "network"
        }
    }

    func isActive(_ item: LatticeHubItem) -> Bool {
        switch item {
        case .screenRecorder: return recorder.isRecording
        default: return false
        }
    }

    func iconColor(_ item: LatticeHubItem) -> Color {
        if item == .screenRecorder, recorder.isRecording { return .red }
        return .accentColor
    }

    func hasQuickOptions(_ item: LatticeHubItem) -> Bool {
        item == .clipboard
    }
}
