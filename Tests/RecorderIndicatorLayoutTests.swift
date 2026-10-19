// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderIndicatorLayoutTests {
    static func run(_ suite: TestSuite) {
        MainActor.assumeIsolated {
            var started = 0
            let indicator = RecorderIndicator(onPause: {}, onStop: {}, onDiscard: {}, onStart: { started += 1 })
            defer { indicator.hide() }
            indicator.show(on: NSScreen.main, tooltip: "Recording", pauseTooltip: "Pause",
                resumeTooltip: "Resume", stopTooltip: "Stop", startTooltip: "Play", discardTooltip: "Trash")
            let selection = CGRect(x: 200, y: 180, width: 600, height: 400)
            indicator.setWaitingForStart(in: selection)
            guard let window = indicator.presentationWindow else { suite.expect(false, "recording indicator exists"); return }
            let cameraOverlay = RecorderOverlayPanel()
            defer { cameraOverlay.close() }
            suite.expect(window.level.rawValue > cameraOverlay.level.rawValue,
                         "recording controls remain above even a full-area camera overlay")
            suite.expectClose(window.frame.midX, 500, "initial Play/Cancel is centered horizontally in the selection")
            suite.expectClose(window.frame.midY, 380, "initial Play/Cancel is centered vertically in the selection")
            func buttons() -> [NSButton] {
                window.contentView?.subviews.compactMap { $0 as? NSButton }.filter { !$0.isHidden } ?? []
            }
            suite.expect(buttons().count == 2, "before first recording only Play and Cancel are visible")
            buttons().first(where: { $0.toolTip == "Play" })?.performClick(nil)
            suite.expect(started == 1, "initial Play starts the recording once")
            indicator.update(elapsed: "0:01")
            indicator.update(paused: true)
            suite.expect(buttons().count == 3 && buttons().contains { $0.toolTip == "Resume" },
                         "a paused recording shows Resume, Stop and Trash")
            suite.expect(window.frame.midY != selection.midY, "mid-recording pause keeps controls at the screen top")
        }
    }
}
