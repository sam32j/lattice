// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Mission Control can keep modifier events in Dock. Sample only Shift, only
/// while windows are selected; no event interception or app activation is needed.
final class ScreenshotMultiWindowShiftMonitor {
    private var timer: Timer?
    private let shiftIsPressed: () -> Bool
    private let canConfirm: () -> Bool
    private let released: () -> Void

    init(shiftIsPressed: @escaping () -> Bool = {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
    }, canConfirm: @escaping () -> Bool = { true }, released: @escaping () -> Void) {
        self.shiftIsPressed = shiftIsPressed
        self.canConfirm = canConfirm
        self.released = released
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, !self.shiftIsPressed(), self.canConfirm() else { return }
            self.stop()
            self.released()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }
}
