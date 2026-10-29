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
        case .windowLayout:
            switch l10n.language {
            case .enUS: return "Window Snapping"
            case .ptBR: return "Ajuste de janelas"
            case .tr: return "Pencere hizalama"
            case .ru: return "Привязка окон"
            case .es: return "Ajuste de ventanas"
            case .sk: return "Prichytávanie okien"
            case .de: return "Fenster-Snapping"
            case .fr: return "Alignement des fenêtres"
            case .it: return "Allineamento finestre"
            case .ja: return "ウインドウスナップ"
            case .ko: return "윈도우 스냅"
            case .zhHans: return "窗口贴边"
            case .zhTW, .zhHK: return "視窗靠齊"
            case .uk: return "Прив’язування вікон"
            }
        case .homebrew: return l10n.s.homebrewName
        case .media: return l10n.s.mediaName
        case .urlCleaner: return l10n.s.urlCleanerName
        case .uninstaller: return l10n.s.uninstallerName
        case .cleaner: return l10n.s.cleanerName
        case .scratchpad: return FeatureStrings.scratchpad(l10n.language).pageTitle
        case .appUpdates: return FeatureStrings.appUpdates(l10n.language).pageTitle
        case .portManager: return FeatureStrings.portManager(l10n.language).title
        case .videoDownloader: return FeatureStrings.videoDownloader(l10n.language).pageTitle
        case .shelf: return l10n.s.shelfName
        case .textSnippets: return FeatureStrings.snippets(l10n.language).pageTitle
        case .killProcess: return FeatureStrings.killProcess(l10n.language).pageTitle
        case .wallpaper: return FeatureStrings.wallpaper(l10n.language).pageTitle
        }
    }

    func icon(for item: LatticeHubItem) -> String {
        switch item {
        case .screenshot: return "camera.viewfinder"
        case .screenRecorder: return recorder.isRecording ? "stop.circle" : "record.circle"
        case .cameraPreview: return "person.crop.square.badge.camera"
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
        case .wallpaper: return "photo.on.rectangle"
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
