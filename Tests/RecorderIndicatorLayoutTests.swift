// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderIndicatorLayoutTests {
    static func run(_ suite: TestSuite) {
        MainActor.assumeIsolated {
            let indicator = RecorderIndicator(onPause: {}, onStop: {}, onDiscard: {})
            defer { indicator.hide() }
            indicator.show(on: NSScreen.main, tooltip: "Recording", pauseTooltip: "Pause",
                resumeTooltip: "Resume", stopTooltip: "Stop", discardTooltip: "Trash")
            let selection = CGRect(x: 200, y: 180, width: 600, height: 400)
            let domain = "vorss.tests.RecorderWaitingControlsTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: domain)!
            defer { defaults.removePersistentDomain(forName: domain) }
            let audio = RecorderSelectionAudioOptions(defaults: defaults)
            let waiting = RecorderWaitingControls(audio: audio, start: {}, cancel: {})
            defer { waiting.hide() }
            waiting.show(in: selection, screen: CGRect(x: 0, y: 0, width: 1200, height: 800))
            guard let window = indicator.presentationWindow else { suite.expect(false, "recording indicator exists"); return }
            let cameraOverlay = RecorderOverlayPanel()
            defer { cameraOverlay.close() }
            suite.expect(window.level.rawValue > cameraOverlay.level.rawValue,
                         "recording controls remain above even a full-area camera overlay")
            suite.expectClose(waiting.panel.frame.midX, 500, "waiting controls are centered horizontally in the selection")
            suite.expectClose(waiting.panel.frame.midY, 380, "waiting controls are centered vertically in the selection")
            suite.expect(!waiting.panel.canBecomeKey && !waiting.panel.canBecomeMain,
                         "waiting controls cannot steal keyboard ownership from the selection")
            suite.expect(waiting.panel.level.rawValue > Int(CGShieldingWindowLevel()) + 1,
                         "waiting controls remain above the selection and waiting camera")
            func buttons() -> [NSButton] {
                window.contentView?.subviews.compactMap { $0 as? NSButton }.filter { !$0.isHidden } ?? []
            }
            indicator.update(elapsed: "0:01")
            indicator.update(paused: true)
            suite.expect(buttons().count == 3 && buttons().contains { $0.toolTip == "Resume" },
                         "a paused recording shows Resume, Stop and Trash")
            suite.expect(window.frame.midY != selection.midY, "mid-recording pause keeps controls at the screen top")
        }
    }
}
