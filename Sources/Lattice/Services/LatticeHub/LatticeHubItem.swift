// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import SwiftUI

/// Pure workflow utilities hosted in Lattice Hub.
enum LatticeHubItem: String, PanelOrderItem, Identifiable {
    case screenshot, screenRecorder, recentCaptures, cleaner, uninstaller, clipboard, windowLayout,
         media, urlCleaner, scratchpad,
         homebrew, appUpdates, portManager, videoDownloader, shelf,
         textSnippets, killProcess, wallpaper, deviceControls

    var id: String { rawValue }

    func isAvailable(in defaults: UserDefaults = .standard) -> Bool {
        feature.isAvailable(in: defaults)
    }

    /// The hub feature behind the tile; off in the hub removes it from the
    /// grid, the hidden list and edit mode until it returns.
    var feature: AppFeature {
        switch self {
        case .screenshot, .recentCaptures: return .screenshot
        case .cleaner: return .cleaner
        case .uninstaller: return .uninstaller
        case .clipboard: return .clipboardHistory
        case .windowLayout: return .windowLayout
        case .media: return .mediaTools
        case .urlCleaner: return .urlCleaner
        case .scratchpad: return .scratchpad
        case .screenRecorder: return .screenRecorder
        case .homebrew: return .homebrew
        case .appUpdates: return .appUpdates
        case .portManager: return .portManager
        case .videoDownloader: return .videoDownloader
        case .shelf: return .shelf
        case .textSnippets: return .textSnippets
        case .killProcess: return .killProcess
        case .wallpaper: return .wallpaper
        case .deviceControls: return .mixer
        }
    }

    func title(language: AppLanguage = L10n.shared.language) -> String {
        let s = Strings.localized(language)
        switch self {
        case .screenshot: return FeatureStrings.screenshot(language).pageTitle
        case .screenRecorder: return FeatureStrings.recorder(language).pageTitle
        case .clipboard: return FeatureStrings.clipboard(language).title
        case .windowLayout:
            switch language {
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
        case .homebrew: return s.homebrewName
        case .media: return s.mediaName
        case .urlCleaner: return s.urlCleanerName
        case .uninstaller: return s.uninstallerName
        case .cleaner: return s.cleanerName
        case .scratchpad: return FeatureStrings.scratchpad(language).pageTitle
        case .appUpdates: return FeatureStrings.appUpdates(language).pageTitle
        case .portManager: return FeatureStrings.portManager(language).title
        case .videoDownloader: return FeatureStrings.videoDownloader(language).pageTitle
        case .shelf: return s.shelfName
        case .textSnippets: return FeatureStrings.snippets(language).pageTitle
        case .killProcess: return FeatureStrings.killProcess(language).pageTitle
        case .wallpaper: return FeatureStrings.wallpaper(language).pageTitle
        case .recentCaptures: return FeatureStrings.recentCaptures(language).title
        case .deviceControls:
            switch language {
            case .enUS: return "Device Controls"
            case .ptBR: return "Controles do dispositivo"
            case .tr: return "Aygıt Denetimleri"
            case .ru: return "Управление устройством"
            case .es: return "Controles del dispositivo"
            case .sk: return "Ovládanie zariadenia"
            case .de: return "Gerätesteuerung"
            case .fr: return "Commandes de l’appareil"
            case .it: return "Controlli dispositivo"
            case .ja: return "デバイスコントロール"
            case .ko: return "기기 제어"
            case .zhHans: return "设备控制"
            case .zhTW, .zhHK: return "裝置控制"
            case .uk: return "Керування пристроєм"
            }
        }
    }
}
