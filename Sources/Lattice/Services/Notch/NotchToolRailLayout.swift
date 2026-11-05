// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension NotchLayout {
    static let hubEditingStripHeight: CGFloat = 60
    static let hubOptionsHeight: CGFloat = 118
    static let hubEmptyHeight: CGFloat = 160
    static let toolTwoRowThreshold = 8
    static let hubWidgetTileHeight: CGFloat = 45

    static func hubIslandWidgetsHeight(in defaults: UserDefaults = .standard) -> CGFloat {
        let hasWidget = NotchSupport.modules(in: defaults).contains { [.music, .calendar, .timer].contains($0) }
        return hasWidget ? hubWidgetTileHeight : 0
    }

    /// Presets intentionally keep large catalogs in two rows.
    static func toolRailRows(count: Int, width: CGFloat, height: CGFloat) -> Int {
        guard count < toolTwoRowThreshold else { return 2 }
        return railRows(count: count,
                        perRow: railCapacity(width: width, itemWidth: toolWidth, spacing: toolSpacing),
                        rowHeight: toolHeight, spacing: toolSpacing, height: height)
    }
}

extension NotchGeometry {
    var hubColumns: Int { layout == .spacious ? 6 : 5 }
    /// Both modes keep the same rail. Hidden tools scroll horizontally in a
    /// fixed strip, so the number hidden never changes the island's height.
    func hubContentHeight(toolCount: Int, controlsHeight: CGFloat,
                          editing: Bool, optionsHeight: CGFloat = 0,
                          widgetsHeight: CGFloat = 0) -> CGFloat {
        let rail = toolCount == 0 ? NotchLayout.hubEmptyHeight : HubStripLayout.contentSize(count: toolCount, columns: hubColumns).height
        let spacing: CGFloat = controlsHeight > 0 ? 6 : 0
        let widgetGap: CGFloat = widgetsHeight > 0 ? 6 : 0
        let normal = controlsHeight + spacing + widgetsHeight + widgetGap + rail
        return normal + (editing ? NotchLayout.hubEditingStripHeight + optionsHeight : 0)
    }
}
