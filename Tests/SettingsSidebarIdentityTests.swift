// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum SettingsSidebarIdentityTests {
    static func run(_ suite: TestSuite) {
        let sections = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in true })
        suite.expect(sections.count == Set(sections.map(\.id)).count,
                     "synthetic sidebar categories never collide with enumerated app or capture groups")
        suite.expect(sections.contains { $0.id == 4 } && sections.contains { $0.id == 2 },
                     "app settings and device controls keep independent collapse identities")
        let lattice = sections.first { $0.id == 4 }
        suite.expect(lattice?.title == "Lattice"
                     && lattice?.items.map(\.id) == [.page(.about), .page(.dataPermissions)],
                     "Lattice contains only About followed by Data and Permissions")
        let interface = sections.first { $0.id == 0 }?.items.map(\.id) ?? []
        suite.expect(interface.contains(.page(.commandBar)),
                     "Interface contains Command Bar")
        let withKeyboard = Directory.sidebarSections(.enUS, language: .enUS,
                            keyboardLightSupported: true, isAvailable: { _ in true })
        let deviceControls = withKeyboard.first { $0.id == 2 }?.items ?? []
        let deviceControlIDs = deviceControls.map(\.id)
        suite.expect(deviceControlIDs == [.page(.audio),
                                          .page(.keyboard), .page(.mouse),
                                          .feature(.brightness)],
                     "Device Controls contains Audio, Keyboard, Mouse, and Display & Energy, with Bluetooth on that page")
        let audioRow = deviceControls.first { $0.id == .page(.audio) }
        suite.expect(audioRow?.title == "Audio" && audioRow?.icon == "speaker.wave.2",
                     "Device Controls shows one Audio entry with a speaker symbol")
        let audioPage = Directory.sections(.enUS, language: .enUS).flatMap(\.items).first { $0.page == .audio }
        let audioAnchors = Dictionary(
            zip(audioPage?.keywords ?? [], audioPage?.keywordAnchors ?? []).map { ($0, $1) },
            uniquingKeysWith: { first, _ in first })
        let strings = Strings.enUS
        suite.expect(audioPage.map {
                    $0.keywordAnchors.count == $0.keywords.count
                        && $0.keywordFeatures.count == $0.keywords.count
                        && $0.keywordRequirements.count == $0.keywords.count
                } == true
                && audioAnchors["Audio Input"] == .micMute
                && audioAnchors["Audio Output"] == .mixer
                && audioAnchors[strings.manageAudioInputPriorityTitle] == .audioPriority
                && audioAnchors[strings.manageAudioOutputPriorityTitle] == .audioOutputPriority
                && audioAnchors[strings.microphoneControlEnable] == .micMute
                && audioAnchors[strings.volumeMixerEnable] == .mixer,
                     "Audio search keywords land on the Input or Output section that holds them")
        suite.expect(!withKeyboard.flatMap(\.items).contains {
            $0.id == .setting(.keyboardBrightnessShortcuts)
        }, "Keyboard Light is moved into Keyboard settings and not in the sidebar")
        let utilityItems = withKeyboard.first { $0.id == 3 }?.items ?? []
        suite.expect(utilityItems.contains { $0.id == .feature(.keepAwake) },
                     "Stay awake is in the Utilities section")
        suite.expect(utilityItems.map(\.title) == utilityItems.map(\.title).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }, "Utilities section items are sorted alphabetically")
        let desktop = sections.first { $0.id == 1 }?.items ?? []
        suite.expect(desktop.map(\.id) == [.page(.dock), .page(.windowLayout), .page(.screenshot)],
                     "Desktop & Screen exposes one Capture entry, and the switcher lives in Dock & Applications")
        suite.expect(SettingsSidebarSupport.selection(
            for: AppFeature.switcher.settingsDestination, in: desktop) == .page(.dock),
            "switcher links select Dock & Applications in the sidebar")
        suite.expect(SettingsSidebarSupport.selection(
            for: FeatureSettingsDestination(.screenRecorder, sectionAnchor: .screenRecorder),
            in: desktop) == .page(.screenshot),
            "recording deep links keep Capture selected in the sidebar")
        suite.expect(SettingsSidebarSupport.selection(
            for: FeatureSettingsDestination(.captureScreenshotOptions),
            in: desktop) == .page(.screenshot),
            "Screenshot Options keeps Capture selected in the sidebar")
        suite.expect(!sections.flatMap(\.items).contains { $0.id == .feature(.pastePlain) || $0.id == .page(.wallpaper) },
                     "Clipboard exposes one page rather than entries for its child controls, and wallpaper dedicated page is removed")
        let off = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in false })
        suite.expect(off.first { $0.id == 1 }?.items.contains { $0.id == .page(.screenshot) } == true
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .page(.screenRecorder) } == false
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .page(.dock) } == true
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .feature(.switcher) } == false
                     && off.first { $0.id == 1 }?.items.contains { $0.id == .page(.windowLayout) } == true,
                     "Capture stays in the sidebar even when both capture features are uninstalled")
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
        }, "unsupported hardware controls are absent from the actual sidebar")
        suite.expect(unsupported.flatMap(\.items).contains { $0.id == .feature(.brightness) }
                     && !unsupported.flatMap(\.items).contains { $0.id == .feature(.bluetoothSleep) },
                     "Display & Energy, which holds Bluetooth, remains reachable independently of optional hardware controls")
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
