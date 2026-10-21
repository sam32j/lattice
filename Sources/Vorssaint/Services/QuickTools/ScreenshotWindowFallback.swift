// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics

extension ScreenshotSupport {
    /// A display crop is not an independent window capture. Require the whole
    /// target on this display and no overlapping foreground pickable window.
    static func canUseFrozenWindowCapture(windowID: UInt32, frame: CGRect,
                                         viewSize: CGSize, windows: [PickableWindow]) -> Bool {
        guard !frame.isEmpty, CGRect(origin: .zero, size: viewSize).contains(frame),
              let index = windows.firstIndex(where: { $0.windowID == windowID }),
              windows[index].frame == frame else { return false }
        return !windows[..<index].contains { !$0.frame.intersection(frame).isEmpty }
    }
}
