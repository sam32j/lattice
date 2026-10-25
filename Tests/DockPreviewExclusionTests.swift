// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import Foundation

enum DockPreviewExclusionTests {
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.dock-preview-target-exclusions.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { return }
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set([" com.example.private ", "com.example.private", "/usr/bin/python3"], forKey: DefaultsKey.windowPreviewExcludedApps)
        defaults.set(["com.example.other"], forKey: DefaultsKey.switcherPreviewExcludedApps)
        suite.expect(DockPreviewExclusions.contains(bundleIdentifier: "com.example.private", in: defaults),
                     "a listed Dock app is excluded independently of which app is in front")
        suite.expect(DockPreviewExclusions.contains(bundleIdentifier: nil, executablePath: "/usr/bin/python3", in: defaults),
                     "an app identified by executable path is excluded")
        suite.expect(!DockPreviewExclusions.contains(bundleIdentifier: nil, executablePath: "/usr/bin/other", in: defaults),
                     "an unlisted executable path is not excluded")
        suite.expect(!DockPreviewExclusions.contains(bundleIdentifier: "com.example.other", in: defaults),
                     "other Dock apps remain available, including an app excluded only from switcher capture")
        suite.expect(!DockPreviewExclusions.contains(bundleIdentifier: nil, in: defaults),
                     "an unidentified app cannot match a named exclusion")
        defaults.set([], forKey: DefaultsKey.windowPreviewExcludedApps)
        suite.expect(!DockPreviewExclusions.contains(bundleIdentifier: "com.example.private", in: defaults),
                     "removing an exclusion takes effect immediately without cached membership")
        suite.expect(SettingsAppListStrings.text(.enUS).disabledApps == "Disable in these apps",
                     "every app list sheet uses the shared disable title")
        let copy = SettingsAppListDescriptions.text(.enUS)
        suite.expect(copy.dockPreview == "Apps in this list will not show dock preview"
            && copy.maximizeWindows == "Apps in this list will still open in a full-screen space."
            && copy.autoQuit == "Apps in this list will not auto quit.",
            "app list descriptions explain each exclusion's behavior")
    }
}
