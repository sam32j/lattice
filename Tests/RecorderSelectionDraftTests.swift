// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderSelectionDraftTests {
    static func run(_ suite: TestSuite) {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        var draft = RecorderSelectionDraft(rect: CGRect(x: 100, y: 100, width: 300, height: 200))
        suite.expect(draft.rect == CGRect(x: 100, y: 100, width: 300, height: 200)
                     && !draft.drag(to: CGPoint(x: 200, y: 200), within: bounds),
                     "recording drafts preserve their initial rectangle and start without an active drag")
        draft.begin(at: CGPoint(x: 400, y: 300))
        draft.drag(to: CGPoint(x: 500, y: 350), within: bounds)
        suite.expect(draft.rect == CGRect(x: 100, y: 100, width: 400, height: 250),
                     "waiting recording selection resizes from its corner")
        draft.end()
        draft.begin(at: CGPoint(x: 200, y: 200))
        draft.drag(to: CGPoint(x: 1000, y: 1000), within: bounds)
        suite.expect(draft.rect == CGRect(x: 400, y: 350, width: 400, height: 250),
                     "moving the draft clamps it without changing recording dimensions")
        draft.end()
        let previous = draft.rect
        draft.begin(at: .zero)
        let changed = draft.drag(to: CGPoint(x: 10, y: 10), within: bounds)
        suite.expect(!changed && draft.rect == previous,
                     "an outside drag reports no geometry change, preserving window-capture identity")
        draft.end()
        draft.begin(at: previous.origin)
        draft.drag(to: CGPoint(x: previous.maxX, y: previous.maxY), within: bounds)
        suite.expect(draft.rect == previous, "a collapsed recording draft is rejected")
    }
}
