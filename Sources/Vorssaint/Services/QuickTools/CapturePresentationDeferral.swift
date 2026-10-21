// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Main-thread, latest-only presentation handoff. Capture storage and copying
/// happen before this queue; only the visual preview waits for desktop landing.
final class CapturePresentationDeferral {
    private var pending: (id: UUID, action: () -> Void)?
    var hasPending: Bool { pending != nil }

    func enqueue(id: UUID, action: @escaping () -> Void) {
        pending = (id, action)
    }

    func cancel(id: UUID) {
        if pending?.id == id { pending = nil }
    }

    func restore() {
        finish(restore: true)
    }

    func finish(restore: Bool) {
        let action = pending?.action
        pending = nil
        if restore { action?() }
    }
}
