// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum FinderRemovalTests {
    static func run(_ suite: TestSuite) {
        let retired = Set(["finderCutPaste", "finderRename"])
        suite.expect(retired.isDisjoint(with: AppFeature.allCases.map(\.rawValue)),
                     "removed Finder additions cannot be installed or restored from the feature catalog")
        let retiredPreferences = ["finderCutPasteEnabled", "finderCutPasteShowHUD", "finderRenameEnabled",
                                  "finderRenameShortcut", "finderPasteImageAsFile", "panelControlCutPaste"]
        suite.expect(retiredPreferences.allSatisfy { Defaults.registeredDefaults[$0] == nil },
                     "removed Finder controls have no registered preferences")
        suite.expect(retiredPreferences.allSatisfy { !SettingsBackupSupport.exportKeys().contains($0) },
                     "backup exports do not preserve removed Finder controls")
    }
}
