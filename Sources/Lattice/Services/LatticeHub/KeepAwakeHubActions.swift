// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension KeepAwakeManager {
    var hubIsTimed: Bool {
        isActive && endDate != nil && sessionMinutes != nil
    }

    func toggleFromHub() {
        if isActive { toggle() } else { activate(minutes: 60) }
    }

    func addHubDuration(minutes: Int) {
        if hubIsTimed { extend(minutes: minutes) } else { activate(minutes: minutes) }
    }

    func reconcileHubSession() {
        // Opening options must never start an inactive session via automation.
        guard isActive else { return }
        syncWithPreferences()
    }
}
