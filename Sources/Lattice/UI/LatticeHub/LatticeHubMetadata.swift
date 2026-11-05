// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubView {
    func title(for item: LatticeHubItem) -> String {
        if item == .screenRecorder, recorder.isRecording {
            return FeatureStrings.recorder(l10n.language).stopButton
        }
        if item == .deviceControls {
            return DeviceControlsNavigationState.shared.currentSubpage == .appVolumes
                ? "App Volumes"
                : item.title(language: l10n.language)
        }
        return item.title(language: l10n.language)
    }

    func icon(for item: LatticeHubItem) -> String {
        switch item {
        case .screenshot: return "camera.viewfinder"
        case .screenRecorder: return recorder.isRecording ? "stop.circle" : "record.circle"
        case .recentCaptures: return "photo.stack"
        case .clipboard: return "doc.on.clipboard"
        case .windowLayout: return "rectangle.3.group"
        case .homebrew: return "shippingbox"
        case .media: return "rectangle.compress.vertical"
        case .urlCleaner: return "link"
        case .uninstaller: return "externaldrive.badge.minus"
        case .cleaner: return "sparkle"
        case .scratchpad: return "note.text"
        case .appUpdates: return "square.and.arrow.down.badge.clock"
        case .portManager: return "network"
        case .videoDownloader: return "arrow.down.circle.dotted"
        case .shelf: return "tray.full"
        case .textSnippets: return "text.append"
        case .killProcess: return "xmark.octagon"
        case .wallpaper: return "rectangle.inset.filled.and.cursorarrow"
        case .deviceControls: return "slider.horizontal.3"
        case .aiUsage: return "apple.intelligence"
        case .watch: return "photo.badge.magnifyingglass"
        case .system: return "gauge.with.dots.needle.50percent"
        }
    }

    func iconColor(_ item: LatticeHubItem) -> Color {
        if item == .screenRecorder, recorder.isRecording { return .red }
        return Color.primary.opacity(0.85)
    }

    func hasQuickOptions(_ item: LatticeHubItem) -> Bool {
        item == .clipboard
    }
}
