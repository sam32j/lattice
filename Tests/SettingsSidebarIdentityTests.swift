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
            in: keyboardRows) == FeatureSettingsDestination(.keyboard),
            "cleaning mode history destination falls back to keyboard page")
    }
}
