// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// How worrying a reading is, decided once for every surface: the menu bar
/// bars and dot, the island's System widget rings and the detail chips. Usage
/// turns elevated at 70% and critical at 90%; what runs out (battery) turns
/// elevated at 20% left and critical at 10%. Memory follows the pressure
/// macOS reports rather than how much is in use, since a full memory is
/// normal on a Mac and pressure is what slows it down.
enum MonitorLevel: Int, Comparable {
    case normal, elevated, critical

    static let elevatedUsage = 0.70
    static let criticalUsage = 0.90
    static let elevatedRemaining = 0.20
    static let criticalRemaining = 0.10

    static func < (lhs: MonitorLevel, rhs: MonitorLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    /// A 0...1 share in use: CPU, GPU, disk.
    static func usage(_ fraction: Double) -> MonitorLevel {
        guard fraction.isFinite else { return .normal }
        if fraction >= criticalUsage { return .critical }
        if fraction >= elevatedUsage { return .elevated }
        return .normal
    }

    /// A 0...1 share left: battery charge.
    static func remaining(_ fraction: Double) -> MonitorLevel {
        guard fraction.isFinite else { return .normal }
        if fraction <= criticalRemaining { return .critical }
        if fraction <= elevatedRemaining { return .elevated }
        return .normal
    }

    /// Memory pressure, with the share in use only when macOS gave none.
    static func memory(pressure: MemoryPressure?, fraction: Double?) -> MonitorLevel {
        switch pressure {
        case .normal: return .normal
        case .warning: return .elevated
        case .critical: return .critical
        case .unknown, nil: return fraction.map(usage) ?? .normal
        }
    }

    /// The color for a status mark (dot, chip): green while all is well.
    var statusColor: NSColor {
        switch self {
        case .normal: return .systemGreen
        case .elevated: return .systemOrange
        case .critical: return .systemRed
        }
    }

    /// The color for a fill (bar, ring): the plain text color while all is
    /// well, so only a reading that needs attention stands out.
    var fillColor: NSColor {
        switch self {
        case .normal: return .labelColor
        case .elevated: return .systemOrange
        case .critical: return .systemRed
        }
    }
}
