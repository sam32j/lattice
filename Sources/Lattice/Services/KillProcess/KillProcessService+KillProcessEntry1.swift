// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Darwin
import Foundation

/// One row of the live process list: either a single process, or - when
/// grouping is on - a responsible app with every helper process it owns
/// folded into it (`groupedCount > 1`).
struct KillProcessEntry: Identifiable, Equatable {
    let pid: pid_t
    let ppid: pid_t
    let name: String
    let path: String
    let cpuPercent: Double
    let memoryBytes: Double
    let isRegularApp: Bool
    let bundleURL: URL?
    let groupedCount: Int
    let isProtected: Bool
    /// Kernel start time in microseconds. A PID alone is reusable and is not a
    /// safe identity for a destructive action confirmed from an old row.
    let startedAt: UInt64?

    var id: pid_t { pid }
}

/// Lists every running process (via `ps`, the same source
/// `ProcessUsageService` uses for the resource breakdown) and kills,
/// force-kills, restarts, or tears down whole process trees. Backs both the
/// Kill Process settings page and its Command Bar rows, which share this
/// service's cache instead of shelling out twice.
