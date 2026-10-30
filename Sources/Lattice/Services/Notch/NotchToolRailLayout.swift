// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension NotchLayout {
    /// Presets intentionally keep large catalogs in two rows.
    static func toolRailRows(count: Int, width: CGFloat, height: CGFloat) -> Int {
        guard count < 10 else { return 2 }
        return railRows(count: count,
                        perRow: railCapacity(width: width, itemWidth: toolWidth, spacing: toolSpacing),
                        rowHeight: toolHeight, spacing: toolSpacing, height: height)
    }
}
