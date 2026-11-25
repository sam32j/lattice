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
        // Inside System its header names the reading open in it; the Hub's
        // tile is always System, whatever reading was last looked at.
        if item == .system, launcher.activeUtility == .system,
           let metric = SystemNavigationState.shared.selectedMetric {
            return metric.title(l10n.s)
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
        case .media: return LatticeSymbol.mediaSymbol
        case .urlCleaner: return "link"
        case .appManager: return LatticeSymbol.appManagerSymbol
        case .cleaner: return LatticeSymbol.cleanerSymbol
        case .scratchpad: return "note.text"
        case .videoDownloader: return "lattice.video.downloader"
        case .shelf: return "tray.full"
        case .textSnippets: return "text.append"
        case .killProcess: return "waveform.path.ecg"
        case .wallpaper: return "photo.tv"
        case .deviceControls: return "slider.horizontal.3"
        case .aiUsage: return "apple.intelligence"
        case .watch: return "photo.badge.magnifyingglass"
        case .system: return "cpu"
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
