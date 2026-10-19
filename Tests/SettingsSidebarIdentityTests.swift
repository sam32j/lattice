// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum SettingsSidebarIdentityTests {
    static func run(_ suite: TestSuite) {
        let sections = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in true })
        suite.expect(sections.count == Set(sections.map(\.id)).count,
                     "synthetic sidebar categories never collide with enumerated app or capture groups")
        suite.expect(sections.contains { $0.id == 8 } && sections.contains { $0.id == 3 },
                     "app settings and audio keep independent collapse identities")
        let lattice = sections.first { $0.id == 8 }
        suite.expect(lattice?.title == "Lattice"
                     && lattice?.items.map(\.id) == [.page(.about), .page(.dataPermissions)],
                     "Lattice contains only About followed by Data and Permissions")
        let interface = sections.first { $0.id == 0 }?.items.map(\.id) ?? []
        suite.expect(interface.firstIndex(of: .page(.features))
                     == interface.firstIndex(of: .page(.shortcuts)).map { $0 + 1 },
                     "Features follows Keyboard Shortcuts in Interface")
        let withKeyboard = Directory.sidebarSections(.enUS, language: .enUS,
                            keyboardLightSupported: true, isAvailable: { _ in true })
        let energy = withKeyboard.first { $0.id == 2 }?.items ?? []
        let energyIDs = energy.map(\.id)
        suite.expect(energyIDs.firstIndex(of: .setting(.keyboardBrightnessShortcuts))
                     == energyIDs.firstIndex(of: .feature(.brightness)).map { $0 + 1 }
                     && energy.first { $0.id == .setting(.keyboardBrightnessShortcuts) }?.destination
                        == FeatureSettingsDestination(.energy, sectionAnchor: .keyboardBrightnessShortcuts),
                     "Keyboard Light follows Displays and opens its Energy section")
        let withoutKeyboard = Directory.sidebarSections(.enUS, language: .enUS,
                               keyboardLightSupported: false, isAvailable: { _ in true })
        suite.expect(!withoutKeyboard.flatMap(\.items).contains {
            $0.id == .setting(.keyboardBrightnessShortcuts)
        }, "unsupported hardware does not expose Keyboard Light")
        let audio = sections.first { $0.id == 3 }?.items.map(\.id) ?? []
        let desktop = sections.first { $0.id == 1 }?.items ?? []
        suite.expect(desktop.contains { $0.id == .page(.dock) }
                     && !desktop.contains { [.feature(.dockClick), .feature(.spacesOrder), .feature(.windowMaximizer)].contains($0.id) },
                     "Dock and Window Management own their controls without duplicate sidebar entrances")
        suite.expect(desktop.contains { $0.destination.page == AppFeature.wallpaper.settingsDestination.page },
                     "Wallpaper belongs to the Desktop & Dock category")
        suite.expect(!sections.flatMap(\.items).contains { $0.id == .feature(.pastePlain) },
                     "Clipboard exposes one page rather than entries for its child controls")
        let off = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in false })
        suite.expect(off.first { $0.id == 2 }?.items.contains { $0.id == .feature(.brightness) } == true,
                     "supported XDR controls keep Displays discoverable when optional features are off")
        let dockClick = SettingsSearchItem(id: .feature(.dockClick), destination: AppFeature.dockClick.settingsDestination,
                                          title: "Dock clicks", icon: "dock.rectangle", feature: .dockClick)
        suite.expect(SettingsSearchSupport.route(for: dockClick, isAvailable: { _ in false }).destination.page == .dock,
                     "searching an off page-owned control opens its page instead of a retired hub row")
        FeatureHardwareBoundary.unsupported = [.extraBrightness, .fanControl]
        let unsupported = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in false })
        suite.expect(!unsupported.flatMap(\.items).contains {
            $0.id == .feature(.fanControl) || $0.id == .feature(.extraBrightness) || $0.id == .feature(.brightness)
        }, "unsupported hardware controls are absent from the actual sidebar")
        FeatureHardwareBoundary.unsupported = []
        suite.expect(audio == [.page(.audioInput), .page(.audioOutput)],
                     "Audio contains Audio Input followed by Audio Output")
        let clipboardFiles = sections.first { $0.id == 6 }?.items.map(\.id) ?? []
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
