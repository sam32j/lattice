#if LATTICE_DEVELOPMENT
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// `--radial-menu-rendering --output-directory DIR`, run under an isolated
/// `io.github.sam32j.lattice.tests.*` identity: migrates seeded version-1
/// profiles in the real app process, then renders the Radial Menu page, the
/// live wheel with its tab arc and the Middle Click rows in both appearances.
enum RadialMenuRenderingProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier,
              identity.hasPrefix("io.github.sam32j.lattice.tests."),
              let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: identity)
        defaults.register(defaults: Defaults.registeredDefaults)
        defaults.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        var failures: [String] = []

        // Version 1: three wheels, the second owning a shortcut and the tap.
        let general = RadialMenuProfilePreset.general.createProfile(name: "General")
        let media = RadialMenuProfilePreset.media.createProfile(name: "Media")
        let windows = RadialMenuProfilePreset.windowLayout.createProfile(name: "Windows")
        let chord = GlobalShortcut(keyCode: 15, modifiers: [.control, .option, .command]).storageValue
        let legacy: [[String: Any]] = [
            ["id": general.id.uuidString, "name": "General", "color": "accent", "items": [], "shortcut": ""],
            ["id": media.id.uuidString, "name": "Media", "color": "purple", "items": [],
             "shortcut": chord, "mouseButton": "button:5", "trackpadTap": true],
            ["id": windows.id.uuidString, "name": "Windows", "color": "orange", "items": []],
        ]
        defaults.set(try? JSONSerialization.data(withJSONObject: legacy), forKey: DefaultsKey.radialMenuProfiles)
        defaults.set("hold", forKey: DefaultsKey.legacyRadialMenuActivationMode)
        defaults.set(false, forKey: DefaultsKey.legacyRadialMenuAtPointer)
        Defaults.migrateRadialMenuTriggers(defaults: defaults)
        let migrated = RadialMenuSupport.decodeProfiles(defaults.data(forKey: DefaultsKey.radialMenuProfiles))
        print("RADIAL_MIGRATION order=\(migrated.map(\.name)) shortcut=\(defaults.string(forKey: DefaultsKey.radialMenuShortcut) ?? "nil") button=\(defaults.string(forKey: DefaultsKey.radialMenuMouseButton) ?? "nil") gesture=\(defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture) ?? "nil") version=\(defaults.integer(forKey: DefaultsKey.radialMenuSettingsVersion)) mode=\(defaults.object(forKey: DefaultsKey.legacyRadialMenuActivationMode) as Any)")
        if migrated.map(\.name) != ["Media", "General", "Windows"]
            || RadialMenuMouseTrigger.sanitized(defaults.string(forKey: DefaultsKey.radialMenuMouseButton) ?? "")
                .buttonNumber != 5
            || defaults.string(forKey: DefaultsKey.radialMenuShortcut) != chord
            || defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture) != "tap" {
            failures.append("migration")
        }

        // Fill the wheels with real actions for the pictures.
        var filled = [media, general, windows]
        filled[0].color = .purple
        filled[2].color = .orange
        defaults.set(RadialMenuSupport.encodeProfiles(filled), forKey: DefaultsKey.radialMenuProfiles)
        SettingsRefactorProbe.setPreviewAvailability(.radialMenu, enabled: true)
        defaults.set(true, forKey: DefaultsKey.radialMenuEnabled)
        defaults.set("back", forKey: DefaultsKey.radialMenuMouseButton)

        for dark in [false, true] {
            let scheme: ColorScheme = dark ? .dark : .light
            let suffix = dark ? "dark" : "light"
            SettingsRefactorProbe.render("radial-settings-\(suffix)",
                                         view: AnyView(RadialMenuSettings()),
                                         size: CGSize(width: 640, height: 900),
                                         output: output, failures: &failures, colorScheme: scheme)
            RadialMenuService.shared.showRenderingPreview(profiles: filled, highlighted: 1, hoveredTab: 2)
            SettingsRefactorProbe.render("radial-live-\(suffix)",
                                         view: AnyView(RadialMenuView().padding(10)),
                                         size: CGSize(width: 480, height: 480),
                                         output: output, failures: &failures, colorScheme: scheme)
        }
        for dark in [false, true] {
            let scheme: ColorScheme = dark ? .dark : .light
            SettingsRefactorProbe.render("radial-item-editor-\(dark ? "dark" : "light")", view: AnyView(
                RadialItemEditor(text: FeatureStrings.radialMenu(.enUS),
                                 item: RadialMenuItem(kind: .quickToggle, payload: RadialMenuQuickToggle.darkMode.rawValue),
                                 isNew: false, allowsSubmenu: true, profileColor: .purple,
                                 save: { _ in }, delete: {})),
                size: CGSize(width: 460, height: 420), output: output, failures: &failures, colorScheme: scheme)
            SettingsRefactorProbe.render("radial-profile-sheet-\(dark ? "dark" : "light")", view: AnyView(
                RadialProfileEditSheet(profile: filled[0], text: FeatureStrings.radialMenu(.enUS),
                                       cancelTitle: "Cancel", save: { _, _ in })),
                size: CGSize(width: 380, height: 330), output: output, failures: &failures, colorScheme: scheme)
        }
        // A wheel with a submenu, for the tab's appended segment.
        var nested = filled
        let submenu = RadialMenuItem(kind: .submenu, name: "Players",
                                     children: [RadialMenuItem(kind: .media, payload: RadialMenuMediaKey.playPause.rawValue)])
        nested[0].items.append(submenu)
        defaults.set(RadialMenuSupport.encodeProfiles(nested), forKey: DefaultsKey.radialMenuProfiles)
        SettingsRefactorProbe.render("radial-settings-submenu", view: AnyView(RadialMenuSettings(openSubmenuID: submenu.id)),
                                     size: CGSize(width: 640, height: 900), output: output, failures: &failures,
                                     colorScheme: .dark)
        for (name, item) in [("submenu", submenu),
                             ("window", RadialMenuItem(kind: .windowLayout, payload: WindowLayoutAction.nextDisplay.rawValue)),
                             ("control", RadialMenuItem(kind: .tool, payload: RadialMenuTool.keepAwake.rawValue)),
                             ("app-new", RadialMenuItem(kind: .app)),
                             ("app", RadialMenuItem(kind: .app, payload: "/System/Applications/Calculator.app")),
                             ("file-new", RadialMenuItem(kind: .file)),
                             ("file", RadialMenuItem(kind: .file, payload: NSHomeDirectory()))] {
            // The empty ones are what Add opens with.
            let isNew = name.hasSuffix("-new")
            SettingsRefactorProbe.render("radial-item-editor-\(name)", view: AnyView(
                RadialItemEditor(text: FeatureStrings.radialMenu(.enUS), item: item, isNew: isNew,
                                 allowsSubmenu: true, profileColor: .purple,
                                 save: { _ in }, delete: isNew ? nil : {})),
                size: CGSize(width: 460, height: 420), output: output, failures: &failures, colorScheme: .dark)
        }
        SettingsRefactorProbe.setPreviewAvailability(.middleClick, enabled: true)
        defaults.set(true, forKey: DefaultsKey.middleClickEnabled)
        defaults.set(4, forKey: DefaultsKey.middleClickTapFingers)
        defaults.set(4, forKey: DefaultsKey.middleClickClickFingers)
        for gesture in ["tap", "click"] {
            defaults.set(gesture, forKey: DefaultsKey.radialMenuTrackpadGesture)
            for (suffix, scheme) in [("light", ColorScheme.light), ("dark", .dark)] {
                SettingsRefactorProbe.render("middle-click-radial-\(gesture)-\(suffix)",
                                             view: AnyView(ScrollView { MouseSettingsMiddleClickPreview().padding(20) }),
                                             size: CGSize(width: 620, height: 520), output: output,
                                             failures: &failures, colorScheme: scheme)
            }
        }

        defaults.removePersistentDomain(forName: identity)
        for failure in failures { print("RADIAL_RENDERING_FAILED \(failure)") }
        if failures.isEmpty { print("RADIAL_RENDERING_OK output=\(output.path)") }
        exit(failures.isEmpty ? 0 : 1)
    }
}

private struct MouseSettingsMiddleClickPreview: View {
    var body: some View { MouseSettings().middleClickCard }
}
#endif
