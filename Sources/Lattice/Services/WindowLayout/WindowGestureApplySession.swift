// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// One gesture's pending frames. Sessions share a serial executor, but never
/// share pending storage: sealing an old drag cannot consume a newer drag.
final class WindowGestureApplySession<Request> {
    private let lock = NSLock()
    private let schedule: (@escaping () -> Void) -> Void
    private let apply: (Request) -> Void
    private var pending: Request?
    private var draining = false
    private var sealed = false
    private var cancelled = false

    init(schedule: @escaping (@escaping () -> Void) -> Void, apply: @escaping (Request) -> Void) {
        self.schedule = schedule
        self.apply = apply
    }

    var isCancelled: Bool { lock.withLock { cancelled } }
    var isIdle: Bool { lock.withLock { !draining && pending == nil } }

    func cancel() { lock.withLock { cancelled = true } }

    func enqueue(_ request: Request) {
        lock.lock()
        guard !sealed, !cancelled else { lock.unlock(); return }
        pending = request
        let shouldSchedule = !draining
        draining = true
        lock.unlock()
        if shouldSchedule { schedule { self.drain() } }
    }

    func finish(cancelled: Bool = false, completion: @escaping () -> Void) {
        lock.lock()
        guard !sealed else { lock.unlock(); return }
        sealed = true
        self.cancelled = self.cancelled || cancelled
        let final = pending
        pending = nil
        lock.unlock()
        schedule {
            if !self.isCancelled, let final { self.apply(final) }
            completion()
        }
    }

    private func drain() {
        lock.lock()
        guard !sealed, !cancelled else {
            draining = false
            lock.unlock()
            return
        }
        let next = pending
        pending = nil
        lock.unlock()
        if let next { apply(next) }
        lock.lock()
        let again = !sealed && !cancelled && pending != nil
        if !again { draining = false }
        lock.unlock()
        // Yield between writes so ordered snap updates receive live turns.
        if again { schedule { self.drain() } }
    }
}
