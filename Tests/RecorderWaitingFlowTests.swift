// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics

enum RecorderWaitingFlowTests {
    struct Region { let rect: CGRect; let windowID: UInt32? }
    final class View { var recordingDraft: RecorderSelectionDraft? }
    final class Panel {
        let displayID: UInt32 = 7
        let overlayView = View()
    }
    class State {
        static var lastRegion: (UInt32, CGRect)?
        var finished = false
        var acceptsCaptureInput: Bool { !finished }
        var waitingRecordingPanel: Panel?
        var waitingRecordingWindowID: UInt32? = 42
        var outcomes: [Region] = []
        enum Outcome { case region(Region) }
        func region(fromView rect: CGRect, on panel: Panel, windowID: UInt32?) -> Region {
            Region(rect: rect, windowID: windowID)
        }
        func finish(_ outcome: Outcome) {
            guard !finished else { return }
            finished = true
            if case .region(let region) = outcome { outcomes.append(region) }
        }
    }
    static func run(_ suite: TestSuite) {
        let controller = Controller()
        let panel = Panel()
        controller.waitingRecordingPanel = panel
        var draft = RecorderSelectionDraft(rect: CGRect(x: 100, y: 100, width: 300, height: 200))
        draft.begin(at: .zero)
        let changed = draft.drag(to: CGPoint(x: 20, y: 20), within: CGRect(x: 0, y: 0, width: 800, height: 600))
        suite.expect(!changed, "dragging outside a recording draft must not clear window identity")
        panel.overlayView.recordingDraft = draft
        controller.startWaitingRecording()
        controller.startWaitingRecording()
        suite.expect(controller.outcomes.count == 1 && controller.outcomes[0].windowID == 42,
                     "repeated Enter accepts a waiting window capture only once")
        let resized = Controller()
        resized.waitingRecordingPanel = panel
        resized.waitingRecordingWindowID = nil
        draft.begin(at: CGPoint(x: 400, y: 300))
        draft.drag(to: CGPoint(x: 500, y: 400), within: CGRect(x: 0, y: 0, width: 800, height: 600))
        panel.overlayView.recordingDraft = draft
        resized.startWaitingRecording()
        suite.expect(resized.outcomes.first?.rect == draft.rect && resized.outcomes.first?.windowID == nil,
                     "Start reads the final resized area rather than the original mouse-up region")
    }
}
