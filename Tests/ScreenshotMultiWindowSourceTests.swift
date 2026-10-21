// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

extension ScreenshotSelectionRefreshContract {
    @MainActor static func multiWindowSourceChecks(_ suite: TestSuite) async {
        let chooser = Chooser(.screenshot)
        let left = chooser.panels[0], right = chooser.panels[1]
        left.frozenImage = CGImage(excluded: [1001])
        right.frozenImage = CGImage(excluded: [2002])
        let frame = CGRect(x: 10, y: 10, width: 20, height: 20)
        left.overlayView.windows = [.init(windowID: 15, frame: frame)]
        right.overlayView.windows = [.init(windowID: 25, frame: frame)]
        chooser.selectedWindows = [
            15: (.init(windowID: 15, frame: frame), left),
            25: (.init(windowID: 25, frame: frame), right)
        ]
        resolvedWindowSources = []
        chooser.confirmSelectedWindows()
        await drain()
        suite.expect(resolvedWindowSources.count == 2
                     && resolvedWindowSources.contains(where: { $0 == [1001] })
                     && resolvedWindowSources.contains(where: { $0 == [2002] }),
                     "each selected window resolves against its own display, not the first selected display")
        if case .captured(let capture) = chooser.outcome {
            suite.expect(capture.anchorRect == CGRect(x: 10, y: 70, width: 120, height: 20),
                         "a cross-display selection retains the canonical global anchor bounds")
        } else { suite.expect(false, "the cross-display selection completes") }

        let spanning = Chooser(.screenshot)
        let panel = spanning.panels[0]
        spanning.selectedWindows = [
            15: (.init(windowID: 15, frame: CGRect(x: -10, y: 10, width: 30, height: 20)), panel)
        ]
        resolvedWindowSources = []
        spanning.confirmSelectedWindows()
        await drain()
        suite.expect(resolvedWindowSources.count == 1 && resolvedWindowSources[0] == nil,
                     "a window spanning a display boundary never stretches that display's partial crop")

        for multiple in [false, true] {
            let covered = Chooser(.screenshot)
            let panel = covered.panels[0]
            panel.overlayView.windows = [.init(windowID: 99, frame: frame), .init(windowID: 15, frame: frame)]
            resolvedWindowSources = []
            if multiple {
                covered.selectedWindows = [15: (.init(windowID: 15, frame: frame), panel)]
                covered.confirmSelectedWindows()
            } else { covered.confirmWindow(15, frame: frame, on: panel) }
            await drain()
            suite.expect(resolvedWindowSources.count == 1 && resolvedWindowSources[0] == nil,
                         "covered windows never use foreground-window display pixels, multiselect: \(multiple)")
        }
    }
}
