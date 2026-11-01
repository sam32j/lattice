// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import CoreGraphics

enum HubEditingLayoutTests {
    static func run(_ suite: TestSuite) {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                     safeAreaTop: 32, cameraWidth: 210)
        let normal = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 11, toolsControlsHeight: 66))
        let editing = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 11, toolsControlsHeight: 66,
            hubIsEditing: true, hubAvailableCount: 1))
        suite.expect(abs(editing.height - normal.height - 60) < 0.5,
                     "editing preserves the display rail and adds only the 60-point Available Tools strip")
        let crowded = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 11, toolsControlsHeight: 66,
            hubIsEditing: true, hubAvailableCount: 40))
        suite.expect(crowded == editing, "hidden tools scroll in a bounded strip instead of growing or clipping the editor")
        suite.expect(NotchLayout.toolRailRows(count: 8, width: 900, height: 320) == 2,
                     "eight apps use two rows even when all eight could fit across")
        let empty = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 0, toolsControlsHeight: 0))
        suite.expect(empty.height >= 160, "an all-hidden hub reserves room for its complete empty state and action")
    }
}
