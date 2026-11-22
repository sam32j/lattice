// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// `--switcher-rendering --output-directory DIR`: draws the real switcher
/// views for each layout with the running apps' real icons, so sizes,
/// padding, clipping and labels can be checked without the hotkey. Glass
/// does not survive an offscreen render, so the panels sit on a flat
/// backdrop; the switcher's own preferences are restored afterwards.
enum SwitcherRenderingProbe {
    static func runAndExit() -> Never {
        guard let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        defaults.register(defaults: Defaults.registeredDefaults)
        let keys = [DefaultsKey.switcherSimpleMode, DefaultsKey.switcherIconRowMode,
                    DefaultsKey.switcherPreviewSize, DefaultsKey.switcherMergeTabs]
        // Only what the user had stored comes back; `exit` skips `defer`, so
        // this runs explicitly before the process ends.
        let saved = keys.map { defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?[$0] }
        func restorePreferences() {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        /// Writes one render, counting it only once the file is on disk.
        func write(_ host: NSView, as file: String, failures: inout [String]) -> Bool {
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                failures.append("\(file): no bitmap")
                return false
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                failures.append("\(file): no PNG")
                return false
            }
            do {
                try png.write(to: output.appendingPathComponent(file + ".png"))
                return true
            } catch {
                failures.append("\(file): \(error)")
                return false
            }
        }

        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.localizedName != nil }
            .prefix(11)
        var items: [SwitcherItem] = []
        var windowID: CGWindowID = 1
        guard !apps.isEmpty else {
            print("SWITCHER_RENDERING_FAILED no regular apps running")
            restorePreferences()
            exit(1)
        }
        // The second app has three windows for the window-scope case; with a
        // single app running, that app has them.
        let multiWindowPosition = apps.count > 1 ? 1 : 0
        for (position, app) in apps.enumerated() {
            let count = position == multiWindowPosition ? 3 : 1
            for window in 0..<count {
                items.append(SwitcherItem(id: "\(app.processIdentifier)-\(window)",
                                          title: window == 0 ? "\(app.localizedName!) — Main" : "Document \(window + 1)",
                                          appName: app.localizedName!,
                                          pid: app.processIdentifier,
                                          windowOwnerPID: app.processIdentifier,
                                          windowID: windowID,
                                          isOnScreen: true, isAppHidden: false, isMinimized: false,
                                          isFullscreen: false, isOnHiddenSpace: false,
                                          frame: CGRect(x: 0, y: 0, width: 1200, height: 800)))
                windowID += 1
            }
        }
        // `--preview-size small` draws with that thumbnail size, as a user has it.
        if let sizeIndex = CommandLine.arguments.firstIndex(of: "--preview-size"),
           CommandLine.arguments.indices.contains(sizeIndex + 1) {
            defaults.set(CommandLine.arguments[sizeIndex + 1], forKey: DefaultsKey.switcherPreviewSize)
        }
        let switcher = AppSwitcher.shared
        var failures: [String] = []
        let cases: [(String, Bool, Bool, SwitcherSessionScope, Int, String)] = [
            ("simple-search-few", true, false, .allApps, 0, "z"),
            ("simple-search-none", true, false, .allApps, 0, "qqqq"),
            ("icons-search-few", false, true, .allApps, 0, "z"),
            ("icons-search-none", false, true, .allApps, 0, "qqqq"),
            ("grid-search-few", false, false, .allApps, 0, "z"),
            ("grid-search-none", false, false, .allApps, 0, "qqqq"),
            ("grid-grouped", false, false, .allApps, 2, ""),
            ("simple", true, false, .allApps, 1, ""),
            ("simple-first", true, false, .allApps, 0, ""),
            ("simple-search", true, false, .allApps, 1, "a"),
            ("simple-windows", true, false, .frontmostApp, 1, ""),
            ("icons", false, true, .allApps, 1, ""),
            ("icons-last", false, true, .allApps, items.count - 1, ""),
            ("grid", false, false, .allApps, 1, ""),
        ]
        for (name, simple, icons, scope, selected, query) in cases {
            defaults.set(simple, forKey: DefaultsKey.switcherSimpleMode)
            defaults.set(icons, forKey: DefaultsKey.switcherIconRowMode)
            defaults.set(name == "grid-grouped", forKey: DefaultsKey.switcherMergeTabs)
            let multiWindowPID = apps[apps.index(apps.startIndex, offsetBy: multiWindowPosition)].processIdentifier
            let list = scope == .frontmostApp ? items.filter { $0.pid == multiWindowPID } : items
            switcher.loadForRendering(list, selectedIndex: min(selected, list.count - 1), scope: scope)
            if !query.isEmpty {
                // Size for the whole session first, then filter, as a live search does.
                let matches = list.filter { $0.appName.localizedCaseInsensitiveContains(query)
                    || $0.title.localizedCaseInsensitiveContains(query) }
                switcher.loadForRendering(matches, selectedIndex: 0, scope: scope, query: query, session: list)
            }
            let size = switcher.renderingPanelSize
            for dark in [true, false] {
                let host = NSHostingView(rootView: SwitcherView()
                    .environmentObject(switcher)
                    .frame(width: size.width, height: size.height)
                    .background(Color(white: dark ? 0.16 : 0.86)))
                host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                host.frame = CGRect(origin: .zero, size: size)
                let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = host
                window.orderFront(nil)
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                let file = "\(name)-\(dark ? "dark" : "light")"
                if write(host, as: file, failures: &failures) {
                    print("SWITCHER_RENDERED \(file) panel=\(Int(size.width))x\(Int(size.height)) tileScale=\(switcher.iconRowLayout.tileScale)")
                }
                window.contentView = nil
                window.close()
            }
        }
        // The settings page's layout tiles.
        let size = CGSize(width: 640, height: 150)
        let host = NSHostingView(rootView: SwitcherLayoutTilesPreview().frame(width: size.width, height: size.height))
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        if write(host, as: "settings-layout-tiles", failures: &failures) {
            print("SWITCHER_RENDERED settings-layout-tiles")
        }
        window.contentView = nil
        window.close()
        for failure in failures { print("SWITCHER_RENDERING_FAILED \(failure)") }
        restorePreferences()
        exit(failures.isEmpty ? 0 : 1)
    }
}
#endif
