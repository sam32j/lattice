// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Shared compact reading for Stay Awake's Hub and island surfaces.
enum KeepAwakeTimeFormat {
    static func compact(end: Date?, now: Date) -> String {
        guard let end else { return "∞" }
        let remaining = end.timeIntervalSince(now)
        guard remaining.isFinite else { return "1′" }
        if remaining <= 180 * 60 {
            return "\(max(1, Int(ceil(max(0, remaining) / 60))))′"
        }
        let quarters = Int(min(Double(Int32.max), (remaining / (15 * 60)).rounded()))
        let fraction = ["", "¼", "½", "¾"][quarters % 4]
        return "\(quarters / 4)\(fraction)hr"
    }
}
