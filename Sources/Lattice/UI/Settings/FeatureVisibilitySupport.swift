// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The Settings pages. Lives here (without SwiftUI) so the visibility rules
/// below and the unit tests can reason about pages without pulling UI in.
enum SettingsPage: Hashable {
    case general, features, energy, monitor, cameraPreview, diskImageInstaller, launcherGrid
    case mouse, keyboard, switcher, dock, wallpaper, cleaner, uninstaller, urlCleaner, homebrew, appUpdates, media, clipboard, windowLayout, shelf, audioInput, audioOutput, scratchpad, textSnippets, screenshot, screenRecorder, radialMenu, commandBar, killProcess, portManager, notch, notchMascot, notchWidget(NotchModule), notchCompanion
    case shortcuts, dataPermissions, about, videoDownloader
}

/// Stable, non-localized identities for destinations inside shared Settings
/// pages. Raw values may be persisted or used by UI identifiers, so cases can
/// be added but never renamed.
enum SettingsSectionAnchor: String, CaseIterable, Hashable {
    case panelConfiguration
    case mixer
    case audioPriority
    case audioOutputPriority
    case musicBlocking
    case keepAwake
    case brightness
    case extraBrightness
    case bluetoothSleep
    case scrollDirection
    case focusFollowsMouse
    case smoothScroll
    case linearScroll
    case mouseAcceleration
    case mouseNavigation
    case mouseButtonShortcuts
    case middleClick
    case mouseClickDebounce
    case switcher
    case dock
    case dockClick
    case autoQuit
    case spacesOrder
    case clipboardHistory
    case pastePlain
    case quickLauncher
    case screenshot
    case screenRecorder
    case micMute
    case cameraPreview
    case wallpaper
    case scratchpad
    case cleaningMode
    case soundOutputSwitcher
    case keyboardBrightnessShortcuts
    case fanControl
    case windowMaximizer
    case quitProtection
    case keyboardDebounce
    case superKey

    var page: SettingsPage {
        switch self {
        case .panelConfiguration:
            return .general
        case .mixer, .musicBlocking, .soundOutputSwitcher, .audioOutputPriority:
            return .audioOutput
        case .audioPriority, .micMute:
            return .audioInput
        case .keepAwake, .brightness, .extraBrightness, .bluetoothSleep, .wallpaper:
            return .energy
        case .scrollDirection, .focusFollowsMouse, .smoothScroll, .linearScroll, .mouseAcceleration, .mouseNavigation, .mouseButtonShortcuts,
             .middleClick, .mouseClickDebounce:
            return .mouse
        case .quitProtection, .keyboardDebounce, .superKey, .cleaningMode, .keyboardBrightnessShortcuts:
            return .keyboard
        case .scratchpad:
            return .scratchpad
        case .switcher: return .switcher
        case .dock, .dockClick: return .dock
        case .autoQuit: return .windowLayout
        case .clipboardHistory, .pastePlain: return .clipboard
        case .quickLauncher: return .launcherGrid
        case .cameraPreview: return .cameraPreview
        case .screenshot:
            return .screenshot
        case .screenRecorder:
            return .screenRecorder
        case .fanControl: return .monitor
        case .windowMaximizer, .spacesOrder: return .windowLayout
        }
    }
}

/// A feature's nearest configuration surface. The optional anchor distinguishes
/// a feature section on a shared page; nil means the page itself is the target.
struct FeatureSettingsDestination: Hashable {
    let page: SettingsPage
    let sectionAnchor: SettingsSectionAnchor?

    init(_ page: SettingsPage, sectionAnchor: SettingsSectionAnchor? = nil) {
        self.page = page
        self.sectionAnchor = sectionAnchor
    }

    var hasValidSectionAnchor: Bool {
        sectionAnchor == nil || sectionAnchor?.page == page
    }
}

struct SettingsDestinationRequest: Equatable {
    let id: UUID
    let destination: FeatureSettingsDestination
}

/// A one-shot request to reveal a specific feature's row inside the Features
/// hub, correlated with the destination request that carries it by sharing
/// the same request id.
struct SettingsFeatureTargetRequest: Equatable {
    let id: UUID
    let feature: AppFeature
}


extension AppFeature {
    /// The hub itself is the honest fallback for features without a separate
    /// configuration surface, but linking a row back to its current page would
    /// present a chevron that appears to do nothing.
    var hasNavigableSettingsDestination: Bool {
        settingsDestination.page != .features
    }

    /// Exhaustive by design: adding an AppFeature requires choosing its
    /// Settings destination before the project compiles.
    var settingsDestination: FeatureSettingsDestination {
        switch self {
        case .switcher: return FeatureSettingsDestination(.switcher, sectionAnchor: .switcher)
        case .dockPreview: return FeatureSettingsDestination(.dock, sectionAnchor: .dock)
        case .dockClick: return FeatureSettingsDestination(.dock, sectionAnchor: .dockClick)
        case .spacesOrder: return FeatureSettingsDestination(.windowLayout, sectionAnchor: .spacesOrder)
        case .windowMaximizer:
            return FeatureSettingsDestination(.windowLayout, sectionAnchor: .windowMaximizer)
        case .windowLayout: return FeatureSettingsDestination(.windowLayout)
        case .autoQuit: return FeatureSettingsDestination(.windowLayout, sectionAnchor: .autoQuit)
        case .quitWindowProtection:
            return FeatureSettingsDestination(.keyboard, sectionAnchor: .quitProtection)

        case .scrollInverter, .scrollHorizontal:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .scrollDirection)
        case .focusFollowsMouse:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .focusFollowsMouse)
        case .smoothScroll:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .smoothScroll)
        case .linearScroll:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .linearScroll)
        case .mouseAcceleration:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .mouseAcceleration)
        case .mouseNavigation:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .mouseNavigation)
        case .mouseButtonShortcuts:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .mouseButtonShortcuts)
        case .middleClick:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .middleClick)
        case .mouseClickDebounce:
            return FeatureSettingsDestination(.mouse, sectionAnchor: .mouseClickDebounce)
        case .keyboardDebounce:
            return FeatureSettingsDestination(.keyboard, sectionAnchor: .keyboardDebounce)
        case .textSnippets: return FeatureSettingsDestination(.textSnippets)
        case .superKey:
            return FeatureSettingsDestination(.keyboard, sectionAnchor: .superKey)

        case .clipboardHistory:
            return FeatureSettingsDestination(.clipboard, sectionAnchor: .clipboardHistory)
        case .pastePlain:
            return FeatureSettingsDestination(.clipboard, sectionAnchor: .pastePlain)
        case .shelf: return FeatureSettingsDestination(.shelf)
        case .urlCleaner: return FeatureSettingsDestination(.urlCleaner)
        case .diskImageInstaller: return FeatureSettingsDestination(.diskImageInstaller)

        case .mixer:
            return FeatureSettingsDestination(.audioOutput, sectionAnchor: .mixer)
        case .soundOutputSwitcher:
            return FeatureSettingsDestination(.audioOutput, sectionAnchor: .soundOutputSwitcher)
        case .audioPriority:
            return FeatureSettingsDestination(.audioInput, sectionAnchor: .audioPriority)
        case .micMute:
            return FeatureSettingsDestination(.audioInput, sectionAnchor: .micMute)
        case .musicBlock:
            return FeatureSettingsDestination(.audioOutput, sectionAnchor: .musicBlocking)

        case .keepAwake:
            return FeatureSettingsDestination(.energy, sectionAnchor: .keepAwake)
        case .brightness:
            return FeatureSettingsDestination(.energy, sectionAnchor: .brightness)
        case .extraBrightness:
            return FeatureSettingsDestination(.energy, sectionAnchor: .extraBrightness)
        case .bluetoothSleep:
            return FeatureSettingsDestination(.energy, sectionAnchor: .bluetoothSleep)

        case .quickLauncher:
            return FeatureSettingsDestination(.launcherGrid)
        case .colorPicker, .screenOCR:
            return FeatureSettingsDestination(.screenshot)
        case .cleaningMode:
            return FeatureSettingsDestination(.keyboard, sectionAnchor: .cleaningMode)
        case .mediaTools: return FeatureSettingsDestination(.media)
        case .cleaner: return FeatureSettingsDestination(.cleaner)
        case .uninstaller: return FeatureSettingsDestination(.uninstaller)
        case .killProcess: return FeatureSettingsDestination(.killProcess)
        case .portManager: return FeatureSettingsDestination(.portManager)
        case .homebrew: return FeatureSettingsDestination(.homebrew)
        case .appUpdates: return FeatureSettingsDestination(.appUpdates)
        case .screenshot:
            return FeatureSettingsDestination(.screenshot, sectionAnchor: .screenshot)
        case .cameraPreview:
            return FeatureSettingsDestination(.cameraPreview)
        case .videoDownloader:
            return FeatureSettingsDestination(.videoDownloader)
        case .wallpaper:
            return FeatureSettingsDestination(.energy, sectionAnchor: .wallpaper)
        case .notch, .notchCalendar, .notchNotifications, .notchGestures, .notchTimer, .notchAccessories, .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchAgents, .notchWatch: return FeatureSettingsDestination(.notch)
        case .notchMascot: return FeatureSettingsDestination(.notchMascot)
        case .radialMenu: return FeatureSettingsDestination(.radialMenu)
        case .scratchpad:
            return FeatureSettingsDestination(.scratchpad, sectionAnchor: .scratchpad)
        case .commandBar: return FeatureSettingsDestination(.commandBar)
        case .screenRecorder:
            return FeatureSettingsDestination(.screenRecorder, sectionAnchor: .screenRecorder)

        case .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower, .connectedDevices:
            return FeatureSettingsDestination(.monitor)
        case .fanControl:
            return FeatureSettingsDestination(.monitor, sectionAnchor: .fanControl)
        }
    }
}

/// Feature ownership for Settings navigation and permission requirements.
/// Ownership is independent of activation: disabled pages stay reachable.
enum FeatureVisibilitySupport {
    static let monitorFeatures: [AppFeature] = [
        .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
        .connectedDevices, .fanControl,
    ]

    /// Features configured by a page; empty means an app-level destination.
    static func features(for page: SettingsPage) -> [AppFeature] {
        switch page {
        case .energy: return [.keepAwake, .brightness, .extraBrightness, .bluetoothSleep, .wallpaper]
        case .monitor: return monitorFeatures
        case .switcher: return [.switcher]
        case .dock: return [.dockPreview, .dockClick]
        case .windowLayout: return [.windowLayout, .windowMaximizer, .autoQuit, .spacesOrder]
        case .wallpaper: return [.wallpaper]
        case .clipboard: return [.clipboardHistory, .pastePlain]
        case .shelf: return [.shelf]
        case .media: return [.mediaTools]
        case .scratchpad: return [.scratchpad]
        case .urlCleaner: return [.urlCleaner]
        case .cleaner: return [.cleaner]
        case .homebrew: return [.homebrew]
        case .appUpdates: return [.appUpdates]
        case .uninstaller: return [.uninstaller]
        case .killProcess: return [.killProcess]
        case .portManager: return [.portManager]
        case .textSnippets: return [.textSnippets]
        case .notch, .notchCompanion: return [.notch, .notchCalendar, .notchNotifications, .notchGestures, .notchTimer, .notchAccessories, .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchAgents, .notchWatch, .notchMascot]
        case .notchMascot: return [.notchMascot]
        case .notchWidget: return [.notch]
        case .radialMenu: return [.radialMenu]
        case .commandBar: return [.commandBar]
        case .screenshot: return [.screenshot, .screenOCR, .colorPicker]
        case .screenRecorder: return [.screenRecorder]
        case .cameraPreview: return [.cameraPreview]
        case .diskImageInstaller: return [.diskImageInstaller]
        case .launcherGrid: return [.quickLauncher]
        case .videoDownloader: return [.videoDownloader]
        case .general, .features, .shortcuts, .dataPermissions, .about, .mouse, .keyboard, .audioInput, .audioOutput:
            return []
        }
    }

    static func isPageVisible(_ page: SettingsPage,
                              isAvailable: (AppFeature) -> Bool) -> Bool {
        // Every feature owns activation on a reachable page. The retired hub
        // is retained only as a legacy routing identity.
        page != .features
    }

    /// Whether one of `page`'s features is among `activeFeatures`, the live
    /// users of a permission from `AppFeature.activeFeatures(using:)`. A page
    /// that several features share asks for the grant while any of them uses it.
    static func isPermissionNeeded(on page: SettingsPage,
                                   activeFeatures: [AppFeature]) -> Bool {
        features(for: page).contains(where: activeFeatures.contains)
    }
}
