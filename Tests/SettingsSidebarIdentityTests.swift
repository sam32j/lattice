// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum SettingsSidebarIdentityTests {
    static func run(_ suite: TestSuite) {
        let sections = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in true })
        suite.expect(sections.count == Set(sections.map(\.id)).count,
                     "synthetic sidebar categories never collide with enumerated app or capture groups")
        suite.expect(sections.contains { $0.id == 5 } && sections.contains { $0.id == 2 },
                     "app settings and device controls keep independent collapse identities")
        let lattice = sections.first { $0.id == 5 }
        suite.expect(lattice?.title == "Lattice"
                     && lattice?.items.map(\.id) == [.page(.about), .page(.dataPermissions)],
                     "Lattice contains only About followed by Data and Permissions")
        let interface = sections.first { $0.id == 0 }?.items.map(\.id) ?? []
        suite.expect(interface.firstIndex(of: .page(.features))
                     == interface.firstIndex(of: .page(.launcherGrid)).map { $0 + 1 },
                     "Features follows Launcher Grid in Interface")
        let withKeyboard = Directory.sidebarSections(.enUS, language: .enUS,
                            keyboardLightSupported: true, isAvailable: { _ in true })
        let deviceControls = withKeyboard.first { $0.id == 2 }?.items ?? []
        let deviceControlIDs = deviceControls.map(\.id)
        suite.expect(deviceControlIDs == [.page(.audioInput), .page(.audioOutput),
                                          .page(.keyboard), .page(.mouse),
                                          .feature(.brightness), .feature(.bluetoothSleep)],
                     "Device Controls contains Audio Input, Audio Output, Keyboard, Mouse, Displays, and Bluetooth Behavior")
        suite.expect(!withKeyboard.flatMap(\.items).contains {
            $0.id == .setting(.keyboardBrightnessShortcuts)
        }, "Keyboard Light is moved into Keyboard settings and not in the sidebar")
        let systemItems = withKeyboard.first { $0.id == 4 }?.items ?? []
        suite.expect(systemItems.first?.id == .feature(.keepAwake),
                     "Stay awake is in the System section")
        let desktop = sections.first { $0.id == 1 }?.items ?? []
        suite.expect(desktop.map(\.id) == [.page(.dock), .feature(.switcher), .page(.windowLayout),
                                           .page(.screenshot), .page(.screenRecorder)],
                     "Desktop & Screen contains 1-5 items: dock, switcher, window layout, screenshot, screen recorder")
        suite.expect(!sections.flatMap(\.items).contains { $0.id == .feature(.pastePlain) || $0.id == .page(.wallpaper) },
                     "Clipboard exposes one page rather than entries for its child controls, and wallpaper dedicated page is removed")
        let off = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in false })
        suite.expect(off.first { $0.id == 1 }?.items.contains { $0.id == .page(.screenshot) } == true
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .page(.screenRecorder) } == true
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .page(.dock) } == true
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .feature(.switcher) } == true
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .page(.windowLayout) } == true,
                     "dock, switcher, window layout, screenshot, and screen recorder remain visible on sidebar even when uninstalled")
        suite.expect(off.flatMap(\.items).contains { $0.id == .page(.notch) },
                     "Dynamic Island remains in the sidebar when it and every extension are uninstalled")
        for feature in [AppFeature.notch, .notchTimer] {
            let item = SettingsSearchItem(id: .feature(feature), destination: feature.settingsDestination,
                                         title: feature.rawValue, icon: feature.symbolName, feature: feature)
            suite.expect(SettingsSearchSupport.route(for: item, isAvailable: { _ in false }).destination.page == .notch,
                         "uninstalled Island controls stay discoverable through search")
        }
        suite.expect(off.first { $0.id == 2 }?.items.contains { $0.id == .feature(.brightness) } == true,
                     "supported XDR controls keep Displays discoverable when optional features are off")
        let dockClick = SettingsSearchItem(id: .feature(.dockClick), destination: AppFeature.dockClick.settingsDestination,
                                          title: "Dock clicks", icon: "dock.rectangle", feature: .dockClick)
        suite.expect(SettingsSearchSupport.route(for: dockClick, isAvailable: { _ in false }).destination.page == .dock,
                     "searching an off page-owned control opens its page instead of a retired hub row")
        FeatureHardwareBoundary.unsupported = [.extraBrightness, .fanControl]
        let unsupported = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in false })
        suite.expect(!unsupported.flatMap(\.items).contains {
            $0.id == .feature(.fanControl) || $0.id == .feature(.extraBrightness)
        } && unsupported.flatMap(\.items).contains { $0.id == .feature(.brightness) },
                     "unsupported hardware-only controls are absent but Displays remains reachable")
        FeatureHardwareBoundary.unsupported = []
        let clipboardFiles = sections.first { $0.id == 3 }?.items.map(\.id) ?? []
        suite.expect(clipboardFiles.contains(.page(.scratchpad))
                     && clipboardFiles.contains(.page(.textSnippets)),
                     "Clipboard and Files includes Scratchpad and Text Snippets")
        let keyboardRows = [SettingsSidebarItem(
            id: .page(.keyboard),
            destination: FeatureSettingsDestination(.keyboard),
            title: "Keyboard", icon: "keyboard")]
        suite.expect(SettingsSidebarSupport.fallbackDestination(
            for: FeatureSettingsDestination(.keyboard, sectionAnchor: .cleaningMode),
            in: keyboardRows) == nil,
            "visible keyboard page preserves the requested cleaning section anchor")
    }
}
