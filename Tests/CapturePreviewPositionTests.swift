// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum CapturePreviewPositionTests {
    static func run(_ suite: TestSuite) {
        let name = "io.github.sam32j.lattice.tests.preview-position.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        suite.expect(ScreenshotSupport.QuickPreviewPosition.current(in: defaults) == .automatic,
                     "both standalone preview types retain automatic placement without a saved preference")
        for position in ScreenshotSupport.QuickPreviewPosition.allCases {
            defaults.set(position.rawValue, forKey: DefaultsKey.screenshotPreviewPosition)
            suite.expect(ScreenshotSupport.QuickPreviewPosition.current(in: defaults) == position,
                         "a shared standalone image/video preview preference retains \(position.rawValue)")
        }
        defaults.set("damaged", forKey: DefaultsKey.screenshotPreviewPosition)
        suite.expect(ScreenshotSupport.QuickPreviewPosition.current(in: defaults) == .automatic,
                     "invalid preview position does not strand a standalone preview offscreen")
    }
}
