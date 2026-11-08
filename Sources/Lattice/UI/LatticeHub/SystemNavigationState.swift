// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import Combine

/// Session-scoped navigation and layout inputs for the System utility.
final class SystemNavigationState: ObservableObject {
    static let shared = SystemNavigationState()

    @Published private(set) var selectedMetric: MetricDetailKind?
    @Published var showMoreProcesses = false
    @Published var showMoreDetails = false
    @Published var showingSpeedTest = false
    @Published var selectedDiskIndex = 0
    @Published private(set) var processCount: Int?

    var processDisplayLimit: Int { showMoreProcesses ? 6 : 3 }
    var displayedProcessCount: Int { max(1, min(processCount ?? 3, processDisplayLimit)) }

    func updateProcessCount(_ count: Int, loading: Bool) {
        let next = loading ? nil : min(count, 6)
        if processCount != next { processCount = next }
    }

    func selectMetric(_ kind: MetricDetailKind?) {
        showMoreProcesses = false
        showMoreDetails = false
        showingSpeedTest = false
        selectedDiskIndex = 0
        processCount = nil
        selectedMetric = kind
    }

    func reset() { selectMetric(nil) }
}
