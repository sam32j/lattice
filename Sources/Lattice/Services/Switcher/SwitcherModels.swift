// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics

enum SwitcherAppIconCache {
    private static let lock = NSLock()
    private static var icons: [pid_t: NSImage]?

    static func beginSession() {
        lock.withLock { icons = [:] }
    }

    static func endSession() {
        lock.withLock { icons = nil }
    }

    /// Resolve only through system icon APIs. Reading a target app's preference
    /// domain here can enter protected data and prompt merely from a Dock hover.
    static func icon(for pid: pid_t,
                     systemIcon: (pid_t) -> NSImage? = systemBundleIcon) -> NSImage? {
        if let cached = lock.withLock({ icons?[pid] }) { return cached }
        guard let source = systemIcon(pid) else { return nil }
        let appearance = NSApplication.shared.effectiveAppearance
        let resolved = NSImage(size: source.size, flipped: false) { rect in
            appearance.performAsCurrentDrawingAppearance { source.draw(in: rect) }
            return true
        }
        // Outside a switcher session, Dock previews resolve the current icon.
        lock.withLock { icons?[pid] = resolved }
        return resolved
    }

    private static func systemBundleIcon(pid: pid_t) -> NSImage? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? app.icon
    }
}

enum WindowSwitchMinimizedPlacement: String, CaseIterable {
    case normal
    case end
    case hidden
}

/// One selectable entry in the switcher. Most entries are real user-facing
/// windows; Finder can also appear as an app entry when it has no windows, so
/// the user can still switch to the desktop/menu bar like the system switcher.
struct SwitcherItem: Identifiable, Equatable {
    let id: String
    let title: String
    let appName: String
    /// The regular app represented by this entry. App grouping, icons, MRU,
    /// activation and quit actions use this process.
    let pid: pid_t
    /// The process that actually owns `windowID`. Multi-process apps can render
    /// their user-facing windows in an embedded accessory helper.
    let windowOwnerPID: pid_t
    /// The backing CGWindow: thumbnails and AX raising go through it.
    let windowID: CGWindowID?
    let isOnScreen: Bool
    let isAppHidden: Bool
    let isMinimized: Bool
    let isFullscreen: Bool
    /// The window belongs only to Spaces that are not currently visible.
    let isOnHiddenSpace: Bool
    /// Window-server coordinates, top-left origin: `kCGWindowBounds`, or the
    /// Accessibility position and size when the window server has no usable
    /// bounds. Never an AppKit (bottom-left) frame, so it can be compared with
    /// `CGDisplayBounds` directly. `.zero` for an entry without a window.
    let frame: CGRect

    /// The window whose thumbnail represents this entry.
    var previewWindowID: CGWindowID? { windowID }

    /// Label shown under the thumbnail; untitled windows fall back to the app name.
    var displayTitle: String {
        title.isEmpty ? appName : title
    }

    func windowLabel(noOpenWindow: String) -> String {
        isAppEntry ? noOpenWindow : displayTitle
    }

    /// The line under an app's name, when there is one worth reading. A window
    /// titled after its own app would only repeat the line above it, which is
    /// the same rule `displaySubtitle` already applies the other way round.
    func windowDetail(noOpenWindow: String) -> String? {
        if isAppEntry { return noOpenWindow }
        return displaySubtitle == nil ? nil : displayTitle
    }

    /// Secondary label used when the window title does not already identify the
    /// app. This keeps crowded switcher grids readable without repeating text.
    var displaySubtitle: String? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAppName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAppName.isEmpty,
              !cleanTitle.isEmpty,
              cleanTitle.caseInsensitiveCompare(cleanAppName) != .orderedSame
        else { return nil }
        return cleanAppName
    }

    var accessibilityTitle: String {
        if let displaySubtitle {
            return "\(displayTitle), \(displaySubtitle)"
        }
        return displayTitle
    }

    /// Whether this entry stands for the app itself because it has no window
    /// to switch to. Those entries have no thumbnail to draw and no window to
    /// name, so several places have to present them differently.
    var isAppEntry: Bool { windowID == nil }

    /// A hidden app follows the minimized-windows placement only when the
    /// user explicitly opts in; an actually minimized window always does.
    func isMinimizedForPlacement(treatHiddenAppsLikeMinimized: Bool) -> Bool {
        isMinimized || (treatHiddenAppsLikeMinimized && isAppHidden)
    }

    /// What the screen reader hears. An app entry replaces the window title
    /// with its state on screen, so the label has to carry that state too or
    /// the entry sounds identical to a window of the same app.
    ///
    /// Lives on the model rather than beside one view: the Dock preview card
    /// draws the same badges and owes its reader the same sentence.
    func spokenLabel(noOpenWindow: String,
                     hiddenApp: String,
                     otherDesktop: String) -> String {
        var label = isAppEntry ? "\(appName), \(noOpenWindow)" : accessibilityTitle
        if isAppHidden { label += ", \(hiddenApp)" }
        if isOnHiddenSpace { label += ", \(otherDesktop)" }
        return label
    }

    /// Use the system icon without reading the target app's preferences.
    /// Reuse the image only while a switcher session is open.
    var appIcon: NSImage? {
        SwitcherAppIconCache.icon(for: pid)
    }

    func withMinimized(_ minimized: Bool) -> SwitcherItem {
        SwitcherItem(id: id,
                     title: title,
                     appName: appName,
                     pid: pid,
                     windowOwnerPID: windowOwnerPID,
                     windowID: windowID,
                     isOnScreen: minimized ? false : true,
                     isAppHidden: isAppHidden,
                     isMinimized: minimized,
                     isFullscreen: isFullscreen,
                     isOnHiddenSpace: isOnHiddenSpace,
                     frame: frame)
    }

    func withHiddenSpaceState(_ hidden: Bool) -> SwitcherItem {
        SwitcherItem(id: id,
                     title: title,
                     appName: appName,
                     pid: pid,
                     windowOwnerPID: windowOwnerPID,
                     windowID: windowID,
                     isOnScreen: isOnScreen,
                     isAppHidden: isAppHidden,
                     isMinimized: isMinimized,
                     isFullscreen: isFullscreen,
                     isOnHiddenSpace: hidden,
                     frame: frame)
    }

    static func window(id: CGWindowID, title: String, appName: String, pid: pid_t,
                       windowOwnerPID: pid_t? = nil,
                       isOnScreen: Bool, isAppHidden: Bool = false,
                       isMinimized: Bool = false,
                       isFullscreen: Bool = false, frame: CGRect) -> SwitcherItem {
        SwitcherItem(id: "w:\(id)", title: title, appName: appName,
                     pid: pid, windowOwnerPID: windowOwnerPID ?? pid,
                     windowID: id, isOnScreen: isOnScreen,
                     isAppHidden: isAppHidden,
                     isMinimized: isMinimized, isFullscreen: isFullscreen,
                     isOnHiddenSpace: false,
                     frame: frame)
    }

    static func appOnly(appName: String, pid: pid_t,
                        isAppHidden: Bool = false) -> SwitcherItem {
        SwitcherItem(id: "a:\(pid)", title: appName, appName: appName,
                     pid: pid, windowOwnerPID: pid, windowID: nil, isOnScreen: false,
                     isAppHidden: isAppHidden,
                     isMinimized: false, isFullscreen: false,
                     isOnHiddenSpace: false, frame: .zero)
    }
}
