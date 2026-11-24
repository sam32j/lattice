// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

/// Accent colors available for radial menu profiles.
enum RadialMenuColor: String, Codable, CaseIterable, Identifiable {
    case accent, blue, purple, pink, red, orange, yellow, green, mint, cyan, indigo, graphite

    var id: String { rawValue }

    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .accent: return .accentColor
        case .blue: return scheme == .light ? Color(red: 0.00, green: 0.48, blue: 1.00) : .blue
        case .purple: return scheme == .light ? Color(red: 0.58, green: 0.20, blue: 0.85) : .purple
        case .pink: return scheme == .light ? Color(red: 0.88, green: 0.16, blue: 0.45) : .pink
        case .red: return scheme == .light ? Color(red: 0.85, green: 0.18, blue: 0.18) : .red
        case .orange: return scheme == .light ? Color(red: 0.95, green: 0.45, blue: 0.00) : .orange
        case .yellow: return scheme == .light ? Color(red: 0.85, green: 0.65, blue: 0.00) : .yellow
        case .green: return scheme == .light ? Color(red: 0.18, green: 0.65, blue: 0.25) : .green
        case .mint: return scheme == .light ? Color(red: 0.00, green: 0.68, blue: 0.60) : .mint
        case .cyan: return scheme == .light ? Color(red: 0.15, green: 0.65, blue: 0.85) : .cyan
        case .indigo: return scheme == .light ? Color(red: 0.35, green: 0.35, blue: 0.85) : .indigo
        case .graphite: return scheme == .light ? Color(white: 0.40) : Color(white: 0.65)
        }
    }

    func title(_ strings: RadialMenuFeatureStrings) -> String {
        switch self {
        case .accent: return strings.colorAccent
        case .blue: return strings.colorBlue
        case .purple: return strings.colorPurple
        case .pink: return strings.colorPink
        case .red: return strings.colorRed
        case .orange: return strings.colorOrange
        case .yellow: return strings.colorYellow
        case .green: return strings.colorGreen
        case .mint: return strings.colorMint
        case .cyan: return strings.colorCyan
        case .indigo: return strings.colorIndigo
        case .graphite: return strings.colorGraphite
        }
    }
}

/// An sRGB color the profile gradients are mixed from. Kept as numbers so
/// the gradient stops and the text contrast can be computed and tested.
struct RadialRGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let white = RadialRGB(red: 1, green: 1, blue: 1)
    static let black = RadialRGB(red: 0, green: 0, blue: 0)

    func mixed(toward other: RadialRGB, by amount: Double) -> RadialRGB {
        RadialRGB(red: red + (other.red - red) * amount,
                  green: green + (other.green - green) * amount,
                  blue: blue + (other.blue - blue) * amount)
    }

    /// WCAG relative luminance.
    var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrast(with other: RadialRGB) -> Double {
        let lighter = max(luminance, other.luminance)
        let darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

extension RadialMenuColor {
    /// The base each gradient is mixed from, per appearance. Light matches
    /// `color(for:)`; dark follows the system's dark palette.
    func baseRGB(for scheme: ColorScheme) -> RadialRGB {
        let light = scheme == .light
        switch self {
        case .accent:
            let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
            return RadialRGB(red: Double(accent.redComponent), green: Double(accent.greenComponent),
                             blue: Double(accent.blueComponent))
        case .blue: return light ? RadialRGB(red: 0.00, green: 0.48, blue: 1.00) : RadialRGB(red: 0.04, green: 0.52, blue: 1.00)
        case .purple: return light ? RadialRGB(red: 0.58, green: 0.20, blue: 0.85) : RadialRGB(red: 0.75, green: 0.35, blue: 0.95)
        case .pink: return light ? RadialRGB(red: 0.88, green: 0.16, blue: 0.45) : RadialRGB(red: 1.00, green: 0.22, blue: 0.37)
        case .red: return light ? RadialRGB(red: 0.85, green: 0.18, blue: 0.18) : RadialRGB(red: 1.00, green: 0.27, blue: 0.23)
        case .orange: return light ? RadialRGB(red: 0.95, green: 0.45, blue: 0.00) : RadialRGB(red: 1.00, green: 0.62, blue: 0.04)
        case .yellow: return light ? RadialRGB(red: 0.85, green: 0.65, blue: 0.00) : RadialRGB(red: 1.00, green: 0.84, blue: 0.04)
        case .green: return light ? RadialRGB(red: 0.18, green: 0.65, blue: 0.25) : RadialRGB(red: 0.19, green: 0.82, blue: 0.35)
        case .mint: return light ? RadialRGB(red: 0.00, green: 0.68, blue: 0.60) : RadialRGB(red: 0.40, green: 0.83, blue: 0.81)
        case .cyan: return light ? RadialRGB(red: 0.15, green: 0.65, blue: 0.85) : RadialRGB(red: 0.39, green: 0.82, blue: 1.00)
        case .indigo: return light ? RadialRGB(red: 0.35, green: 0.35, blue: 0.85) : RadialRGB(red: 0.37, green: 0.36, blue: 0.90)
        case .graphite: return light ? RadialRGB(red: 0.40, green: 0.40, blue: 0.40) : RadialRGB(red: 0.65, green: 0.65, blue: 0.65)
        }
    }

    /// Top-leading and bottom-trailing stops: lifted toward white, sunk
    /// toward black, a little more of each in the light appearance at the
    /// top and in the dark one at the bottom. Graphite stays neutral because
    /// its base is.
    func gradientStops(for scheme: ColorScheme) -> (top: RadialRGB, bottom: RadialRGB) {
        let base = baseRGB(for: scheme)
        let light = scheme == .light
        return (base.mixed(toward: .white, by: light ? 0.18 : 0.10),
                base.mixed(toward: .black, by: light ? 0.22 : 0.30))
    }

    func gradient(for scheme: ColorScheme) -> LinearGradient {
        let stops = gradientStops(for: scheme)
        return LinearGradient(colors: [stops.top.color, stops.bottom.color],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// White text unless white misses 4.5:1 on the darker stop; then dark
    /// text, which that same stop then always clears.
    func usesDarkText(for scheme: ColorScheme) -> Bool {
        gradientStops(for: scheme).bottom.contrast(with: .white) < 4.5
    }

    func foreground(for scheme: ColorScheme) -> Color {
        usesDarkText(for: scheme) ? Color.black.opacity(0.88) : .white
    }
}

/// One wheel of actions with its name and color. The menu opens on the
/// first profile (the primary); the others are tabs inside the menu. What
/// opens the menu (shortcut, mouse button, trackpad gesture) is menu-wide and
/// lives in its own preferences, never in a profile.
struct RadialMenuProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var color: RadialMenuColor = .accent
    var items: [RadialMenuItem] = []
    /// The starter set this wheel was created from, so restoring its actions
    /// brings back that one. Kept as the raw value because it is persisted;
    /// nil for a wheel whose origin is not known.
    var preset: String?

    func displayName(_ text: RadialMenuFeatureStrings) -> String {
        name.isEmpty ? text.presetGeneral : name
    }

    /// The copy Duplicate adds: same actions and color, a new identity.
    func duplicate(named name: String) -> RadialMenuProfile {
        var copy = self
        copy.id = UUID()
        copy.name = name
        return copy
    }
}

extension RadialMenuProfile {
    private enum CodingKeys: String, CodingKey {
        case id, name, color, items, preset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
                  name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
                  color: try container.decodeIfPresent(RadialMenuColor.self, forKey: .color) ?? .accent,
                  items: try container.decodeIfPresent([FailableRadialMenuItem].self, forKey: .items)?
                      .compactMap(\.value) ?? [],
                  preset: try container.decodeIfPresent(String.self, forKey: .preset))
    }
}

private struct FailableRadialMenuProfile: Decodable {
    let value: RadialMenuProfile?

    init(from decoder: Decoder) throws {
        value = try? RadialMenuProfile(from: decoder)
    }
}

/// The triggers profiles carried before they became menu-wide (settings
/// version 1). Read only by the migration, from the same blob, so the
/// profile itself never has to know about them again.
struct RadialMenuLegacyTriggers: Decodable, Equatable {
    var id: UUID?
    var shortcut = ""
    var mouseButton = RadialMenuMouseTrigger.off.rawValue
    var trackpadTap = false

    private enum CodingKeys: String, CodingKey { case id, shortcut, mouseButton, trackpadTap }

    init(id: UUID?, shortcut: String = "", mouseButton: String = RadialMenuMouseTrigger.off.rawValue,
         trackpadTap: Bool = false) {
        self.id = id
        self.shortcut = shortcut
        self.mouseButton = mouseButton
        self.trackpadTap = trackpadTap
    }

    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        id = (try? container?.decodeIfPresent(UUID.self, forKey: .id)) ?? nil
        shortcut = (try? container?.decodeIfPresent(String.self, forKey: .shortcut)) ?? ""
        mouseButton = (try? container?.decodeIfPresent(String.self, forKey: .mouseButton))
            ?? RadialMenuMouseTrigger.off.rawValue
        trackpadTap = (try? container?.decodeIfPresent(Bool.self, forKey: .trackpadTap)) ?? false
    }

    var validShortcut: GlobalShortcut? {
        let trimmed = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : GlobalShortcut(storageValue: trimmed)
    }

    var button: RadialMenuMouseTrigger { RadialMenuMouseTrigger.sanitized(mouseButton) }
}

/// Curated starter presets when creating new profiles.
enum RadialMenuProfilePreset: String, CaseIterable, Identifiable {
    case general, media, tools, windowLayout, quickToggles, blank

    var id: String { rawValue }

    func title(_ strings: RadialMenuFeatureStrings) -> String {
        switch self {
        case .general: return strings.presetGeneral
        case .media: return strings.presetMedia
        case .tools: return strings.presetTools
        case .windowLayout: return strings.presetWindowLayout
        case .quickToggles: return strings.presetQuickToggles
        case .blank: return strings.presetBlank
        }
    }

    var defaultColor: RadialMenuColor {
        switch self {
        case .general: return .accent
        case .media: return .purple
        case .tools: return .cyan
        case .windowLayout: return .orange
        case .quickToggles: return .mint
        case .blank: return .graphite
        }
    }

    func makeItems() -> [RadialMenuItem] {
        switch self {
        case .general:
            return RadialMenuSupport.starterItems
        case .media:
            return [
                RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.playPause.rawValue),
                RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.nextTrack.rawValue),
                RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.nowPlaying.rawValue),
                RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.previousTrack.rawValue),
            ]
        case .tools:
            return [
                RadialMenuItem(kind: .tool, payload: RadialMenuTool.screenshot.rawValue),
                RadialMenuItem(kind: .tool, payload: RadialMenuTool.screenRecorder.rawValue),
                RadialMenuItem(kind: .tool, payload: RadialMenuTool.micMute.rawValue),
                RadialMenuItem(kind: .tool, payload: RadialMenuTool.scratchpad.rawValue),
            ]
        case .windowLayout:
            return [
                RadialMenuItem(kind: .windowLayout, payload: WindowLayoutAction.maximize.rawValue),
                RadialMenuItem(kind: .windowLayout, payload: WindowLayoutAction.rightHalf.rawValue),
                RadialMenuItem(kind: .windowLayout, payload: WindowLayoutAction.bottomHalf.rawValue),
                RadialMenuItem(kind: .windowLayout, payload: WindowLayoutAction.leftHalf.rawValue),
                RadialMenuItem(kind: .windowLayout, payload: WindowLayoutAction.topHalf.rawValue),
            ]
        case .quickToggles:
            return [
                RadialMenuItem(kind: .quickToggle, payload: RadialMenuQuickToggle.darkMode.rawValue),
                RadialMenuItem(kind: .quickToggle, payload: RadialMenuQuickToggle.desktopIcons.rawValue),
                RadialMenuItem(kind: .quickToggle, payload: RadialMenuQuickToggle.hiddenFiles.rawValue),
                RadialMenuItem(kind: .quickToggle, payload: RadialMenuQuickToggle.lockScreen.rawValue),
                RadialMenuItem(kind: .quickToggle, payload: RadialMenuQuickToggle.emptyTrash.rawValue),
            ]
        case .blank:
            return []
        }
    }

    func createProfile(name: String? = nil, color: RadialMenuColor? = nil) -> RadialMenuProfile {
        RadialMenuProfile(id: UUID(),
                           name: name ?? "",
                           color: color ?? defaultColor,
                           items: makeItems(),
                           preset: rawValue)
    }
}

/// One action on the wheel. `payload` carries the target: an app or file path,
/// a link, tool, media or window-layout identifier, or a shortcut storage
/// value. Submenus keep their actions in `children`.
struct RadialMenuItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case app, file, url, shortcut, tool, quickToggle, windowLayout, media, submenu
    }

    var id = UUID()
    var kind = Kind.app
    var name = ""
    var symbolName = ""
    var payload = ""
    var customIconData: Data? = nil
    var children: [RadialMenuItem] = []

    var tool: RadialMenuTool? {
        kind == .tool ? RadialMenuTool(rawValue: payload) : nil
    }

    var mediaKey: RadialMenuMediaKey? {
        kind == .media ? RadialMenuMediaKey(rawValue: payload) : nil
    }

    var quickToggle: RadialMenuQuickToggle? {
        kind == .quickToggle ? RadialMenuQuickToggle(rawValue: payload) : nil
    }

    var windowLayoutAction: WindowLayoutAction? {
        kind == .windowLayout ? WindowLayoutAction(rawValue: payload) : nil
    }

    /// The symbol drawn when the user picked none. App and file items prefer
    /// their real file icons in the UI; these are the fallbacks.
    var defaultSymbolName: String {
        switch kind {
        case .app: return "app"
        case .file: return "folder"
        case .url: return "link"
        case .shortcut: return "command"
        case .tool: return tool?.symbolName ?? "wrench.and.screwdriver"
        case .quickToggle: return quickToggle?.symbolName ?? "togglepower"
        case .windowLayout: return windowLayoutAction?.symbolName ?? AppFeature.windowLayout.symbolName
        case .media:
            switch mediaKey {
            case .previousTrack: return "backward.fill"
            case .nextTrack: return "forward.fill"
            case .nowPlaying: return "waveform"
            default: return "playpause.fill"
            }
        case .submenu: return "ellipsis.circle"
        }
    }

    var effectiveSymbolName: String {
        symbolName.isEmpty ? defaultSymbolName : symbolName
    }
}

/// Quick toggle actions a slice can trigger. Raw values persist inside the
/// items blob; never rename them.
enum RadialMenuQuickToggle: String, Codable, CaseIterable, Identifiable {
    case darkMode, emptyTrash, ejectDisks, hiddenFiles, desktopIcons,
         lockScreen, displayOff, screenSaver

    var id: String { rawValue }

    var isAvailable: Bool {
        true
    }

    /// The name of a toggle whose live title follows the system's state
    /// ("Switch to Dark Mode"), as Settings shows it: what it does, not what
    /// it would do this moment. Nil for toggles whose title never changes.
    func stableTitle(_ text: RadialMenuFeatureStrings) -> String? {
        switch self {
        case .darkMode: return text.toggleSystemAppearance
        case .hiddenFiles: return text.toggleHiddenFiles
        case .desktopIcons: return text.toggleDesktopIcons
        default: return nil
        }
    }

    var symbolName: String {
        switch self {
        case .darkMode: return "moon.fill"
        case .emptyTrash: return "trash"
        case .ejectDisks: return "eject.fill"
        case .hiddenFiles: return "eye"
        case .desktopIcons: return "desktopcomputer"
        case .lockScreen: return "lock.display"
        case .displayOff: return "power.circle"
        case .screenSaver: return "sparkles.tv"
        }
    }
}

// The custom decoder lives in an extension so the memberwise initializer
// stays synthesized. It tolerates blobs written by newer versions: absent
// fields fall back to their defaults, and an unknown kind fails just this
// item, which the lossy array decode below then drops instead of losing the
// whole menu.
extension RadialMenuItem {
    private enum CodingKeys: String, CodingKey {
        case id, kind, name, symbolName, payload, customIconData, children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
                  kind: try container.decode(Kind.self, forKey: .kind),
                  name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
                  symbolName: try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "",
                  payload: try container.decodeIfPresent(String.self, forKey: .payload) ?? "",
                  customIconData: try container.decodeIfPresent(Data.self, forKey: .customIconData),
                  children: try container.decodeIfPresent([FailableRadialMenuItem].self, forKey: .children)?
                      .compactMap(\.value) ?? [])
    }
}

private struct FailableRadialMenuItem: Decodable {
    let value: RadialMenuItem?

    init(from decoder: Decoder) throws {
        value = try? RadialMenuItem(from: decoder)
    }
}

/// Lattice tools a slice can trigger. Raw values persist inside the items
/// blob; never rename them.
enum RadialMenuTool: String, Codable, CaseIterable, Identifiable {
    case screenshot, screenRecorder, colorPicker, screenOCR, micMute, clipboardHistory, quickLauncher,
         cameraPreview, scratchpad, shelf, cleaner, uninstaller, appUpdates, cleaningMode, keepAwake

    var id: String { rawValue }

    var feature: AppFeature {
        switch self {
        case .screenshot: return .screenshot
        case .screenRecorder: return .screenRecorder
        case .colorPicker: return .colorPicker
        case .screenOCR: return .screenOCR
        case .micMute: return .micMute
        case .clipboardHistory: return .clipboardHistory
        case .quickLauncher: return .quickLauncher
        case .cameraPreview: return .cameraPreview
        case .scratchpad: return .scratchpad
        case .shelf: return .shelf
        case .cleaner: return .cleaner
        case .uninstaller: return .uninstaller
        case .appUpdates: return .appUpdates
        case .cleaningMode: return .cleaningMode
        case .keepAwake: return .keepAwake
        }
    }

    var symbolName: String { feature.symbolName }

    /// Switches something on or off rather than opening a utility, the way
    /// the hub groups these features (Sound, Energy & Display, Mouse &
    /// Keyboard). The action editor lists them with the quick controls; they
    /// stay stored as tools.
    var isControl: Bool {
        switch self {
        case .micMute, .keepAwake, .cleaningMode: return true
        default: return false
        }
    }

    /// Hub availability and a feature's own master switch are separate. A
    /// saved Shelf slice stays dormant while Shelf is explicitly disabled and
    /// returns automatically when the user enables it again.
    func isRunnable(isFeatureAvailable: (AppFeature) -> Bool = { $0.isAvailable },
                    boolFor: (String) -> Bool = { UserDefaults.standard.bool(forKey: $0) }) -> Bool {
        if self == .cleaningMode { return true } // This manual action needs no persistent shortcut.
        guard self != .colorPicker, self != .screenOCR, isFeatureAvailable(feature) else { return false }
        return self != .shelf || boolFor(DefaultsKey.shelfEnabled)
    }
}

/// The optional second summoner: any extra mouse button. The original raw
/// values stay stable for existing settings; newer buttons use their
/// CoreGraphics number, which follows USB order from 3 through 31.
enum RadialMenuMouseTrigger: Equatable, Identifiable {
    case off
    case button(Int64)

    static let back = button(MouseButtonShortcutSupport.backButtonNumber)
    static let forward = button(MouseButtonShortcutSupport.forwardButtonNumber)

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .off: return "off"
        case .button(let number):
            if number == MouseButtonShortcutSupport.backButtonNumber { return "back" }
            if number == MouseButtonShortcutSupport.forwardButtonNumber { return "forward" }
            return "button:\(number)"
        }
    }

    var buttonNumber: Int64? {
        guard case .button(let number) = self else { return nil }
        return number
    }

    static func sanitized(_ raw: String?) -> RadialMenuMouseTrigger {
        switch raw {
        case "back": return .back
        case "forward": return .forward
        case let value?:
            guard value.hasPrefix("button:"),
                  let number = Int64(value.dropFirst("button:".count)),
                  MouseButtonShortcutSupport.buttonRange.contains(number) else { return .off }
            return .button(number)
        default: return .off
        }
    }
}

/// The trackpad gesture that opens the menu. Raw values are persisted.
/// Four fingers only: three belong to macOS (Look Up, three-finger drag).
enum RadialMenuTrackpadGesture: String, CaseIterable, Identifiable {
    case off, tap, click

    var id: String { rawValue }

    static func sanitized(_ raw: String?) -> RadialMenuTrackpadGesture {
        RadialMenuTrackpadGesture(rawValue: raw ?? "") ?? .off
    }
}

/// What the pointer (or the arrow keys) has picked when the summoner is
/// released.
enum RadialMenuPreselection: Equatable {
    case none
    case slot
    case submenu
    case profileTab
}

/// What releasing a held shortcut or mouse button does.
enum RadialMenuRelease: Equatable {
    case run, openSubmenu, switchProfile, stayOpen, close
}

extension RadialMenuSupport {
    /// The Super Key is a virtual modifier: it decorates the summoning key but
    /// never appears in the system's current physical-modifier state. A chord
    /// whose modifiers come from a remapped key (a Hyper key, a mouse button
    /// its driver turns into a chord) is the same, so the chord's own key
    /// being down also counts: only letting go of everything ends the hold.
    static func shortcutIsStillHeld(modifiersHeld: Bool, superKeyHeld: Bool, keyHeld: Bool = false) -> Bool {
        modifiersHeld || superKeyHeld || keyHeld
    }

    /// Whether a chord's key coming up ends its hold. A key let go within
    /// the quick-press window was a tap, so the wheel stays open even if a
    /// modifier lingers past that window; a key held longer leaves the hold
    /// to the modifiers, so they can keep aiming. Super Key chords keep
    /// their own release path.
    static func chordKeyUpEndsHold(heldFor: TimeInterval, usesSuperKey: Bool,
                                   modifiersHeld: Bool, superKeyHeld: Bool) -> Bool {
        if !usesSuperKey, heldFor < quickPressLimit { return true }
        return !shortcutIsStillHeld(modifiersHeld: modifiersHeld, superKeyHeld: superKeyHeld)
    }

    /// Whether the radial menu currently owns this extra button as its
    /// summoner. Mouse navigation and the mouse button shortcuts both ask
    /// this from inside their own tap callbacks, on every event of a
    /// side-button gesture, so it reads defaults and the stored buttons only:
    /// never the items, and never `decodeProfiles`, which decodes their
    /// custom icons. Asking never wakes the radial menu service.
    static func claimsMouseButton(_ button: Int64) -> Bool {
        claimsMouseButton(button, defaults: .standard)
    }

    static func claimsMouseButton(_ button: Int64, defaults: UserDefaults) -> Bool {
        guard defaults.bool(forKey: AppFeature.radialMenu.availabilityKey),
              defaults.bool(forKey: DefaultsKey.radialMenuEnabled) else { return false }
        return claimedMouseButton(defaults: defaults) == button
    }

    /// A quick press stays open; a longer hold released over nothing closes.
    static let quickPressLimit: TimeInterval = 0.30
    /// Resting on a profile tab this long while holding switches to it.
    static let tabDwell: TimeInterval = 0.35
    /// How long the hub names the profile just switched to.
    static let profileNameFlash: TimeInterval = 0.8
    /// A hold whose release never arrived (focus changed mid-hold) ends as
    /// sticky after this long, never as a run.
    static let holdSafetyTimeout: TimeInterval = 10

    /// The one decision a release makes, for the shortcut and the mouse
    /// button alike. Anything picked wins over how long the hold lasted.
    static func releaseAction(heldFor: TimeInterval,
                              preselection: RadialMenuPreselection) -> RadialMenuRelease {
        switch preselection {
        case .slot: return .run
        case .submenu: return .openSubmenu
        case .profileTab: return .switchProfile
        case .none: return heldFor < quickPressLimit ? .stayOpen : .close
        }
    }
}

/// Media keys a slice can press, mapped to the aux-button codes the physical
/// keys post (NX_KEYTYPE_PLAY / FAST / REWIND).
enum RadialMenuMediaKey: String, Codable, CaseIterable, Identifiable {
    case playPause, previousTrack, nextTrack, nowPlaying

    var id: String { rawValue }

    /// Now Playing opens Lattice's metadata card rather than posting a key.
    var auxKeyType: Int32? {
        switch self {
        case .playPause: return 16
        case .previousTrack: return 20
        case .nextTrack: return 19
        case .nowPlaying: return nil
        }
    }
}

struct RadialNowPlayingSnapshot: Equatable {
    let title: String?
    let artist: String?
    let album: String?
    let artworkData: Data?
    let appBundleIdentifier: String?
    let appPID: Int32?

    var radialLabel: String? {
        let parts = [title, artist].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
}

enum RadialNowPlayingState: Equatable {
    case loading
    case nothingPlaying
    case playing(RadialNowPlayingSnapshot)
}

enum RadialNowPlayingSupport {
    static let titleKey = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artistKey = "kMRMediaRemoteNowPlayingInfoArtist"
    static let albumKey = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let artworkDataKey = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let playbackRateKey = "kMRMediaRemoteNowPlayingInfoPlaybackRate"

    private static let forbiddenScalars = CharacterSet.controlCharacters.union(.newlines)
    /// The one artwork cap. The adapter (`Sources/NowPlayingAdapter`) drops
    /// artwork above it before encoding, and the bridge's pipe cap is
    /// `maximumAdapterReplyBytes`, sized so the base64 line (4/3 of the bytes,
    /// so 16 MB) plus the other keys fits.
    static let maximumArtworkBytes = 12 * 1_024 * 1_024
    static let maximumAdapterReplyBytes = maximumArtworkBytes / 3 * 4 + 1_024 * 1_024

    static func playbackIsActive(remoteIsPlaying: Bool?, info: [String: Any]) -> Bool {
        if let remoteIsPlaying { return remoteIsPlaying }
        return (info[playbackRateKey] as? NSNumber)?.doubleValue ?? 0 > 0
    }

    /// One reply from the Now Playing adapter (`Resources/now-playing.pl`):
    /// the MediaRemote metadata keys it forwards, plus the owning app and the
    /// remote's own playing flag, in the shape `snapshot(info:...)` reads.
    struct AdapterReply {
        let info: [String: Any]
        let pid: Int32
        let displayID: String?
        let isPlaying: Bool?
    }

    /// Parses the adapter's JSON line, the last non-blank line of the run's
    /// output: stderr shares the pipe, so a perl warning (a locale it cannot
    /// set, say) can precede it. Artwork arrives base64-encoded under
    /// `artworkBase64` and is handed on as `artworkDataKey` bytes. An `error`
    /// key, a non-object or unreadable bytes read as no reply.
    static func adapterReply(from data: Data) -> AdapterReply? {
        let blank: Set<UInt8> = [0x20, 0x09, 0x0D]
        guard let line = data.split(separator: 0x0A).last(where: { $0.contains { !blank.contains($0) } }),
              let object = try? JSONSerialization.jsonObject(with: line),
              let fields = object as? [String: Any],
              fields["error"] == nil else { return nil }
        var info: [String: Any] = [:]
        for key in [titleKey, artistKey, albumKey] {
            if let value = fields[key] as? String { info[key] = value }
        }
        for key in [playbackRateKey, "kMRMediaRemoteNowPlayingInfoDuration",
                    "kMRMediaRemoteNowPlayingInfoElapsedTime"] {
            if let value = fields[key] as? NSNumber { info[key] = value }
        }
        if fields["artworkUnchanged"] as? Bool == true { info["artworkUnchanged"] = true }
        for key in ["canSeek", "canSkipNext", "canSkipPrevious"] {
            if let value = fields[key] as? Bool { info[key] = value }
        }
        if let identifier = fields["itemIdentifier"] as? String, !identifier.isEmpty,
           identifier.utf8.count <= 512, !identifier.contains("\0") { info["itemIdentifier"] = identifier }
        if let artwork = fields["artworkBase64"] as? String,
           let bytes = Data(base64Encoded: artwork), !bytes.isEmpty {
            info[artworkDataKey] = bytes
        }
        return AdapterReply(info: info,
                            pid: (fields["pid"] as? NSNumber)?.int32Value ?? 0,
                            displayID: fields["displayID"] as? String,
                            isPlaying: fields["isPlaying"] as? Bool)
    }

    static func snapshot(info: [String: Any],
                         isPlaying: Bool,
                         appBundleIdentifier: String?,
                         appPID: Int32) -> RadialNowPlayingSnapshot? {
        guard isPlaying else { return nil }
        let title = sanitizedText(info[titleKey])
        let artist = sanitizedText(info[artistKey])
        let album = sanitizedText(info[albumKey])
        let bundleIdentifier = sanitizedBundleIdentifier(appBundleIdentifier)
        let pid = appPID > 0 ? appPID : nil
        let artworkData = sanitizedArtworkData(info[artworkDataKey])
        guard title != nil || bundleIdentifier != nil || pid != nil else { return nil }
        return RadialNowPlayingSnapshot(title: title,
                                        artist: artist,
                                        album: album,
                                        artworkData: artworkData,
                                        appBundleIdentifier: bundleIdentifier,
                                        appPID: pid)
    }

    private static func sanitizedText(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let clean = String(String.UnicodeScalarView(
            trimmed.unicodeScalars.filter { !forbiddenScalars.contains($0) }))
        return clean.isEmpty ? nil : String(clean.prefix(300))
    }

    private static func sanitizedBundleIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 255,
              !trimmed.unicodeScalars.contains(where: { forbiddenScalars.contains($0) })
        else { return nil }
        return trimmed
    }

    private static func sanitizedArtworkData(_ value: Any?) -> Data? {
        guard let data = value as? Data, !data.isEmpty, data.count <= maximumArtworkBytes else {
            return nil
        }
        return data
    }
}

enum RadialMenuSupport {
    /// Pointer events that can update a visible wheel's highlighted slice.
    /// AppKit reports movement with a held extra mouse button as
    /// `otherMouseDragged`, rather than as a plain mouse move.
    static let sessionMoveMask: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .otherMouseDragged,
    ]

    static let maxItemsPerWheel = 12
    /// Root plus one submenu level. Deeper nesting turns the wheel into a maze.
    static let maxDepth = 2

    /// Curated built-in symbols for the editor. The picker filters this list
    /// at runtime so older supported macOS releases only show symbols they own.
    static let symbolNames = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "sparkles",
        "folder.fill", "doc.fill", "tray.full.fill", "terminal.fill", "globe",
        "envelope.fill", "message.fill", "music.note", "headphones", "camera.fill",
        "photo.fill", "video.fill", "gamecontroller.fill", "calendar", "clock.fill",
        "house.fill", "cart.fill", "hammer.fill", "paintbrush.fill", "book.fill",
        "keyboard", "magnifyingglass", "airplane",
        "checkmark.circle.fill", "xmark.circle.fill", "plus.circle.fill", "minus.circle.fill",
        "exclamationmark.triangle.fill", "questionmark.circle.fill", "info.circle.fill",
        "lock.fill", "lock.open.fill", "key.fill", "person.fill", "person.2.fill",
        "bell.fill", "flag.fill", "bookmark.fill", "tag.fill",
        "paperclip", "link", "scissors", "doc.on.clipboard",
        "square.and.arrow.up", "square.and.arrow.down", "trash.fill", "archivebox.fill",
        "externaldrive.fill", "internaldrive.fill", "display", "desktopcomputer",
        "laptopcomputer", "iphone", "ipad", "applewatch",
        "wifi", "network", "antenna.radiowaves.left.and.right",
        "speaker.wave.2.fill", "mic.fill", "waveform",
        "play.fill", "pause.fill", "stop.fill", "backward.fill", "forward.fill",
        "shuffle", "repeat",
        "sun.max.fill", "moon.fill", "lightbulb.fill", "battery.100", "power",
        "eye.fill", "eye.slash.fill", "location.fill", "map.fill",
        "paperplane.fill", "bubble.left.fill", "phone.fill",
        "gearshape.fill", "slider.horizontal.3", "switch.2", "command",
        "printer.fill", "textformat", "number",
    ]

    /// Whether the target can actually run for this kind. The editor blocks
    /// saving what fails here, and `sanitized` drops it, so the two can never
    /// disagree about what belongs on a wheel.
    static func isValidPayload(_ item: RadialMenuItem) -> Bool {
        switch item.kind {
        case .app, .file: return !item.payload.isEmpty
        case .url: return normalizedURL(item.payload) != nil
        case .shortcut: return GlobalShortcut(storageValue: item.payload) != nil
        case .tool: return item.tool.map { $0 != .colorPicker && $0 != .screenOCR } ?? false
        case .quickToggle: return item.quickToggle != nil
        case .windowLayout: return item.windowLayoutAction != nil
        case .media: return item.mediaKey != nil
        case .submenu: return true
        }
    }

    /// Drops what cannot run (unknown tools or media keys, unparseable
    /// shortcuts, empty targets, submenus past the depth cap) and clamps
    /// counts, so the wheel never renders a dead slice.
    static func sanitized(_ items: [RadialMenuItem], depth: Int = 0) -> [RadialMenuItem] {
        guard depth < maxDepth else { return [] }
        var seen = Set<UUID>()
        var result: [RadialMenuItem] = []
        for var item in items {
            guard result.count < maxItemsPerWheel, seen.insert(item.id).inserted else { continue }
            item.name = String(item.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
            item.payload = item.payload.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidPayload(item) else { continue }
            if item.kind == .url, let normalized = normalizedURL(item.payload) {
                item.payload = normalized
            }
            if let customData = item.customIconData {
                if customData.count > RadialMenuFaviconFetcher.maxStoredIconBytes || NSImage(data: customData) == nil {
                    item.customIconData = nil
                }
            }
            if item.kind == .submenu {
                guard depth + 1 < maxDepth else { continue }
                item.children = sanitized(item.children, depth: depth + 1)
            } else {
                item.children = []
            }
            result.append(item)
        }
        return result
    }

    /// A missing blob means a fresh install and yields the starter wheel; a
    /// present blob, even an empty list, is the user's own menu.
    static func decode(_ data: Data?) -> [RadialMenuItem] {
        guard let data else { return starterItems }
        let decoded = (try? JSONDecoder().decode([FailableRadialMenuItem].self, from: data)) ?? []
        return sanitized(decoded.compactMap(\.value))
    }

    static func encode(_ items: [RadialMenuItem]) -> Data? {
        try? JSONEncoder().encode(sanitized(items))
    }

    /// Accepts "example.com/page" style input by assuming https, keeps
    /// explicit schemes (mailto:, app links) as typed, and rejects anything
    /// that cannot become a loadable URL.
    static func normalizedURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if hasExplicitScheme(trimmed) {
            guard let url = URL(string: trimmed) else { return nil }
            if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                return url.host != nil ? trimmed : nil
            }
            return trimmed
        }
        let candidate = "https://" + trimmed
        guard let url = URL(string: candidate), url.host != nil else { return nil }
        return candidate
    }

    /// A leading URL scheme, minding that "example.com:8080" is a host and
    /// port while "tel:5551234" is a scheme: digits after the colon only
    /// mean a port when the part before it looks like a host.
    private static func hasExplicitScheme(_ value: String) -> Bool {
        if value.contains("://") { return true }
        guard value.first?.isLetter == true,
              let colon = value.firstIndex(of: ":"),
              value[..<colon].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." })
        else { return false }
        let after = value.index(after: colon)
        guard after < value.endIndex else { return false }
        guard value[after].isNumber else { return true }
        let prefix = value[..<colon]
        return !prefix.contains(".") && prefix.lowercased() != "localhost"
    }

    /// The wheel a fresh install starts with: media around the top, tools and
    /// the Downloads folder below. Names stay empty so every language derives
    /// its own labels. A single evaluation keeps the seed ids stable for the
    /// whole session, so equality against a decoded seed behaves.
    static let starterItems: [RadialMenuItem] = [
        RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.playPause.rawValue),
        RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.nextTrack.rawValue),
        RadialMenuItem(kind: .tool, payload: RadialMenuTool.screenshot.rawValue),
        RadialMenuItem(kind: .file, payload: "~/Downloads"),
        RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.previousTrack.rawValue),
    ]

    /// True when any item, at any level, controls keyboard input or windows
    /// and therefore needs the Accessibility permission.
    static func needsAccessibility(_ items: [RadialMenuItem]) -> Bool {
        items.contains { item in
            switch item.kind {
            case .shortcut, .windowLayout: return true
            case .media: return item.mediaKey?.auxKeyType != nil
            case .submenu: return needsAccessibility(item.children)
            default: return false
            }
        }
    }

    /// True when any profile, at any level, controls keyboard input or
    /// windows, or the menu opens from a mouse button or a trackpad gesture,
    /// and therefore needs the Accessibility permission.
    static func needsAccessibility(_ profiles: [RadialMenuProfile],
                                   mouseButton: RadialMenuMouseTrigger,
                                   trackpadGesture: RadialMenuTrackpadGesture) -> Bool {
        mouseButton != .off || trackpadGesture != .off
            || profiles.contains { needsAccessibility($0.items) }
    }

    /// The same question read from preferences.
    static func needsAccessibility(_ profiles: [RadialMenuProfile],
                                   defaults: UserDefaults = .standard) -> Bool {
        needsAccessibility(profiles,
                           mouseButton: RadialMenuMouseTrigger.sanitized(
                               defaults.string(forKey: DefaultsKey.radialMenuMouseButton)),
                           trackpadGesture: RadialMenuTrackpadGesture.sanitized(
                               defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture)))
    }

    /// The mouse button that opens the menu, if any. This is the question the
    /// event taps ask on every extra-button event, so it reads one string and
    /// never the profiles.
    static func claimedMouseButton(defaults: UserDefaults = .standard) -> Int64? {
        RadialMenuMouseTrigger.sanitized(defaults.string(forKey: DefaultsKey.radialMenuMouseButton)).buttonNumber
    }

    /// The trackpad gesture the menu holds right now: off unless the feature
    /// is installed and switched on. Middle Click and the contact reader read
    /// this, so its saved gesture is released the moment the menu is off.
    static func effectiveTrackpadGesture(defaults: UserDefaults = .standard,
                                         isAvailable: Bool = AppFeature.radialMenu.isAvailable)
        -> RadialMenuTrackpadGesture {
        guard isAvailable, defaults.bool(forKey: DefaultsKey.radialMenuEnabled) else { return .off }
        return RadialMenuTrackpadGesture.sanitized(defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture))
    }

    /// Whether the menu opens from a mouse button or a trackpad gesture, the
    /// triggers that keep an input tap running while the menu is on.
    static func opensFromMouseOrTrackpad(defaults: UserDefaults = .standard) -> Bool {
        claimedMouseButton(defaults: defaults) != nil
            || RadialMenuTrackpadGesture.sanitized(defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture)) != .off
    }

    /// Decodes profiles from JSON blob. If missing, checks for legacy
    /// items / shortcut / mouse button to migrate existing users, or creates
    /// the starter profile.
    ///
    /// Walks every item on every wheel and decodes each custom icon (up to
    /// `RadialMenuFaviconFetcher.maxStoredIconBytes` of PNG apiece), so it
    /// belongs to settings and session start, never to an event-tap callback.
    /// A callback that only needs the summoner wants `claimedMouseButtons`.
    static func decodeProfiles(_ data: Data?, defaults: UserDefaults = .standard) -> [RadialMenuProfile] {
        if let data, let decoded = try? JSONDecoder().decode([FailableRadialMenuProfile].self, from: data) {
            let sanitized = sanitizedProfiles(decoded.compactMap(\.value))
            if !sanitized.isEmpty { return sanitized }
        }
        // The single wheel that came before profiles. Its shortcut and mouse
        // button already live in the menu-wide keys.
        let items = decode(defaults.data(forKey: DefaultsKey.radialMenuItems))
        let initialProfile = RadialMenuProfile(
            id: legacyProfileID,
            name: "",
            color: .accent,
            items: items,
            // The single wheel that came before profiles started from the
            // general starter set, whatever it was edited into since.
            preset: RadialMenuProfilePreset.general.rawValue
        )
        return [initialProfile]
    }

    static let legacyProfileID = UUID(uuidString: "E0A8948E-5056-4BD3-82D5-5020F99F0001") ?? UUID()


    static func encodeProfiles(_ profiles: [RadialMenuProfile]) -> Data? {
        try? JSONEncoder().encode(sanitizedProfiles(profiles))
    }

    static func sanitizedProfiles(_ profiles: [RadialMenuProfile]) -> [RadialMenuProfile] {
        var seenIDs = Set<UUID>()
        var result: [RadialMenuProfile] = []
        for var profile in profiles {
            guard seenIDs.insert(profile.id).inserted else { continue }
            profile.name = String(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
            profile.items = sanitized(profile.items)
            result.append(profile)
        }
        if result.isEmpty {
            result.append(RadialMenuProfilePreset.general.createProfile())
        }
        return result
    }

    static func containsNowPlaying(_ items: [RadialMenuItem]) -> Bool {
        items.contains { item in
            item.mediaKey == .nowPlaying
                || (item.kind == .submenu && containsNowPlaying(item.children))
        }
    }

    static func usesWindowLayout(_ items: [RadialMenuItem]) -> Bool {
        items.contains { item in
            item.kind == .windowLayout
                || (item.kind == .submenu && usesWindowLayout(item.children))
        }
    }
}

/// Shared wheel dimensions, points. The service positions the panel and maps
/// pointer distances with these; the view draws with them. The panel is a
/// good margin wider than the wheel so its soft shadow fades out naturally
/// instead of being clipped into a visible square.
enum RadialMenuLayout {
    static let panelSize: CGFloat = 400
    /// The panel with the profile tabs' arc above the wheel: the arc sits
    /// `tabArcGap` outside the rim and the panel grows so it never clips.
    static let panelSizeWithTabs: CGFloat = 460
    static let tabArcGap: CGFloat = 14
    static let tabPillHeight: CGFloat = 22
    /// The widest the arc of tabs may spread, centered over twelve o'clock.
    static let tabArcMaxSpan: Double = 2 * .pi / 3
    static var tabArcRadius: CGFloat { wheelDiameter / 2 + tabArcGap + tabPillHeight / 2 }

    static func panelSize(showsTabs: Bool) -> CGFloat {
        showsTabs ? panelSizeWithTabs : panelSize
    }
    static let wheelDiameter: CGFloat = 300
    static let ringRadius: CGFloat = 112
    static let chipSize: CGFloat = 52
    static let hubDiameter: CGFloat = 76
    static let deadZoneRadius: CGFloat = 40
    /// The pointer must travel this far from where the wheel opened before
    /// slices start highlighting, so a center-of-screen wheel never fires on
    /// whatever direction the pointer already happened to sit in.
    static let moveActivationDistance: CGFloat = 8
}

/// Pure slice math shared by the wheel view and the pointer tracking. Slice 0
/// sits at 12 o'clock and indices grow clockwise; angles are measured
/// clockwise from the top in radians.
enum RadialMenuGeometry {
    /// Angle of the vector (dx, dyUp) where dyUp grows toward the top of the
    /// screen, in [0, 2 * pi).
    static func angle(dx: CGFloat, dyUp: CGFloat) -> CGFloat {
        let raw = atan2(dx, dyUp)
        return raw < 0 ? raw + 2 * .pi : raw
    }

    static func index(forAngle angle: CGFloat, itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        let step = 2 * .pi / CGFloat(itemCount)
        let shifted = (angle + step / 2).truncatingRemainder(dividingBy: 2 * .pi)
        let index = Int(shifted / step)
        return min(max(index, 0), itemCount - 1)
    }

    /// The slice under the pointer, nil inside the dead zone around the hub.
    static func highlightedIndex(dx: CGFloat, dyUp: CGFloat,
                                 deadZoneRadius: CGFloat, itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        let distance = (dx * dx + dyUp * dyUp).squareRoot()
        guard distance >= deadZoneRadius else { return nil }
        return index(forAngle: angle(dx: dx, dyUp: dyUp), itemCount: itemCount)
    }

    /// Unit-circle position of a slice center, dyUp toward the screen top.
    static func unitPosition(index: Int, itemCount: Int) -> (dx: CGFloat, dyUp: CGFloat) {
        guard itemCount > 0 else { return (0, 1) }
        let theta = 2 * .pi * CGFloat(index) / CGFloat(itemCount)
        return (sin(theta), cos(theta))
    }
}

/// Fetches a website's favicon for a link action. The Settings editor calls
/// it once typing in the address pauses (and only while no symbol is picked
/// for the action), so the typed host is contacted without a separate
/// request; the icon button's help says so.
enum RadialMenuFaviconFetcher {
    /// Max allowable icon data storage: 64KB
    static let maxStoredIconBytes = 65536
    /// A favicon should be tiny. Stop the transfer itself at this bound so a
    /// hostile response cannot be buffered into unbounded memory first.
    static let maxDownloadBytes = 2 * 1_024 * 1_024
    static let maxSourceDimension = 4_096
    static let maxSourcePixels = 16_777_216

    /// Fetches the favicon for a URL string on-demand.
    /// Runs on a background task, calls completion on main queue.
    static func fetchFavicon(for rawURL: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = faviconURL(for: rawURL) else {
            DispatchQueue.main.async {
                completion(.failure(FaviconError.invalidURL))
            }
            return
        }
        FaviconDownload(url: url, byteLimit: maxDownloadBytes) { result in
            DispatchQueue.main.async {
                guard case let .success(data) = result,
                      sourceDimensionsAreSafe(data),
                      let image = NSImage(data: data),
                      image.size.width > 0, image.size.height > 0,
                      let pngData = scaledPNGData(from: image)
                else {
                    completion(.failure(FaviconError.notFound))
                    return
                }
                completion(.success(pngData))
            }
        }.start()
    }

    static func faviconURL(for rawURL: String) -> URL? {
        guard let normalized = RadialMenuSupport.normalizedURL(rawURL),
              let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        components.user = nil
        components.password = nil
        components.path = "/favicon.ico"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    static func sourceDimensionsAreSafe(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0,
              width <= maxSourceDimension, height <= maxSourceDimension,
              width <= maxSourcePixels / height
        else { return false }
        return true
    }

    static func scaledPNGData(from image: NSImage, targetSize: CGFloat = 64) -> Data? {
        let size = NSSize(width: targetSize, height: targetSize)
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()

        guard let tiffData = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png.count <= maxStoredIconBytes ? png : nil
    }

    enum FaviconError: Error {
        case invalidURL
        case notFound
    }

    private struct Origin: Equatable {
        let scheme: String
        let host: String
        let port: Int

        init?(_ url: URL) {
            guard let scheme = url.scheme?.lowercased(),
                  let host = url.host?.lowercased() else { return nil }
            self.scheme = scheme
            self.host = host
            port = url.port ?? (scheme == "https" ? 443 : 80)
        }
    }

    private final class FaviconDownload: NSObject, URLSessionDataDelegate {
        private let url: URL
        private let byteLimit: Int
        private let completion: (Result<Data, Error>) -> Void
        private let origin: Origin
        private var session: URLSession?
        private var data = Data()
        private var finished = false

        init(url: URL, byteLimit: Int, completion: @escaping (Result<Data, Error>) -> Void) {
            self.url = url
            self.byteLimit = byteLimit
            self.completion = completion
            origin = Origin(url)!
        }

        func start() {
            var request = URLRequest(url: url,
                                     cachePolicy: .reloadIgnoringLocalCacheData,
                                     timeoutInterval: 5)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 5
            let session = URLSession(configuration: configuration,
                                     delegate: self,
                                     delegateQueue: nil)
            self.session = session
            session.dataTask(with: request).resume()
        }

        func urlSession(_ session: URLSession,
                        dataTask: URLSessionDataTask,
                        didReceive response: URLResponse,
                        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  response.expectedContentLength <= 0
                    || response.expectedContentLength <= Int64(byteLimit)
            else {
                completionHandler(.cancel)
                finish(.failure(FaviconError.notFound))
                return
            }
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession,
                        dataTask: URLSessionDataTask,
                        didReceive chunk: Data) {
            guard data.count + chunk.count <= byteLimit else {
                dataTask.cancel()
                finish(.failure(FaviconError.notFound))
                return
            }
            data.append(chunk)
        }

        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        willPerformHTTPRedirection newResponse: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            guard let redirectURL = request.url,
                  Origin(redirectURL) == origin else {
                completionHandler(nil)
                return
            }
            completionHandler(request)
        }

        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        didCompleteWithError error: Error?) {
            if let error {
                finish(.failure(error))
            } else {
                finish(.success(data))
            }
        }

        private func finish(_ result: Result<Data, Error>) {
            guard !finished else { return }
            finished = true
            session?.finishTasksAndInvalidate()
            session = nil
            completion(result)
        }
    }
}
