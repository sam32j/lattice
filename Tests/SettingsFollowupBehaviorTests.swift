// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum SettingsFollowupBehaviorTests {
    static func run(_ suite: TestSuite) {
        let retired = RadialMenuItem(kind: .tool, payload: RadialMenuTool.colorPicker.rawValue)
        let screenshot = RadialMenuItem(kind: .tool, payload: RadialMenuTool.screenshot.rawValue)
        let items = RadialMenuSupport.sanitized([retired, screenshot])
        suite.expect(items.map(\.payload) == [RadialMenuTool.screenshot.rawValue],
                     "legacy Color Picker slices no longer appear in previews or default menus")
    }
}
