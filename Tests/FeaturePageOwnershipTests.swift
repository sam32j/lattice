// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum FeaturePageOwnershipTests {
    static func run(_ suite: TestSuite) {
        suite.expect(KeyboardDebounceKeyCatalog.available(excluding: [0, 11]).allSatisfy { $0.code != 0 && $0.code != 11 }
                     && KeyboardDebounceKeyCatalog.available(excluding: []).count == KeyboardDebounceKeyCatalog.common.count,
                     "the duplicate-key editor excludes configured keys and restores removed keys")
        suite.expect(!GlobalShortcutRole.availableRoles(isAvailable: { _ in true }).contains(.screenOCR)
                     && !GlobalShortcutRole.availableRoles(isAvailable: { _ in true }).contains(.colorPicker)
                     && ScreenCaptureTool.available(isAvailable: { _ in true }) == [.screenshot, .recording],
                     "standalone OCR and color entry points are absent while shared tool operations remain")
        let name = "io.github.sam32j.lattice.tests.page-ownership.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let controls: [(AppFeature, String)] = [
            (.clipboardHistory, DefaultsKey.clipboardHistoryEnabled), (.shelf, DefaultsKey.shelfEnabled),
            (.textSnippets, DefaultsKey.textSnippetsEnabled), (.urlCleaner, DefaultsKey.urlCleanerEnabled),
            (.cameraPreview, AppFeature.cameraPreview.availabilityKey),
            (.diskImageInstaller, AppFeature.diskImageInstaller.availabilityKey),
            (.quickLauncher, AppFeature.quickLauncher.availabilityKey), (.scratchpad, AppFeature.scratchpad.availabilityKey)
        ]
        for (feature, key) in controls {
            defaults.set(true, forKey: key)
            suite.expect(feature.isToggleOwned && feature.isManagedOnDedicatedPage
                         && feature.isAvailable(in: defaults, hardwareSupported: true),
                         "\(feature) installs through its always-reachable page toggle")
            defaults.set(false, forKey: key)
            suite.expect(!feature.isAvailable(in: defaults, hardwareSupported: true)
                         && !AppFeature.hubInstallableFeatures.contains(feature),
                         "\(feature) uninstalls through its page and is absent from Features")
        }
        defaults.set(true, forKey: DefaultsKey.snippetLibraryEnabled)
        suite.expect(!AppFeature.textSnippets.isAvailable(in: defaults, hardwareSupported: true),
                     "a retained library preference cannot install disabled text snippets")
    }
}
