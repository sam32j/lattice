// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension NotchLayout {
    /// Presets intentionally keep large catalogs in two rows. A custom
    /// surface follows the height available to both rendering and navigation.
    static func toolRailRows(count: Int, width: CGFloat, height: CGFloat, custom: Bool) -> Int {
        guard count < 10 || custom else { return 2 }
        return railRows(count: count,
                        perRow: railCapacity(width: width, itemWidth: toolWidth, spacing: toolSpacing),
                        rowHeight: toolHeight, spacing: toolSpacing, height: height)
    }
}
