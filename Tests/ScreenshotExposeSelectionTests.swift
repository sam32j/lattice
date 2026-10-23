// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics

enum ScreenshotExposeSelectionTests {
    static func run(_ suite: TestSuite) {
        // Window order and geometry observed during the failed Exposé capture.
        // WindowManager's full-screen surface must not win the app-window hit.
        let candidates: [(id: CGWindowID, pid: pid_t, owner: String, layer: Int, frame: CGRect)] = [
            (13, 420, "Window Server", 24, CGRect(x: 0, y: 0, width: 1710, height: 38)),
            (7196, 29575, "Dock", 20, CGRect(x: 0, y: 0, width: 1710, height: 1112)),
            (17080, 613, "WindowManager", 19, CGRect(x: 0, y: 0, width: 1710, height: 1112)),
            (17079, 613, "WindowManager", 14, CGRect(x: 0, y: 0, width: 1710, height: 134)),
            (16745, 1643, "Raycast", 8, CGRect(x: 23, y: 485, width: 171, height: 232)),
            (17086, 613, "WindowManager", 2, CGRect(x: 558, y: 580, width: 279, height: 90)),
            (65, 632, "ChatGPT", 0, CGRect(x: 959, y: 650, width: 557, height: 350)),
            (17087, 613, "WindowManager", 0, CGRect(x: 383, y: 474, width: 570, height: 363)),
            (58, 641, "Crest", 0, CGRect(x: 389, y: 480, width: 558, height: 351)),
        ]
        let decorations = ScreenshotCapturePolicy.decorationWindowIDs(frontToBack: candidates
            .filter { $0.layer == 0 }.map {
                .init(id: $0.id, ownerPID: $0.pid, frame: $0.frame, isUntitled: $0.owner == "WindowManager")
            })
        let windows = candidates.filter {
            ScreenshotCapturePolicy.isPickableWindowLayer($0.layer, ownerName: $0.owner)
                && !decorations.contains($0.id)
        }.map { ScreenshotSupport.PickableWindow(windowID: $0.id, frame: $0.frame) }
        suite.expect(ScreenshotSupport.window(at: CGPoint(x: 755.64, y: 680.80), in: windows)?.windowID == 58,
                     "Exposé selects the app under the pointer, not the full-screen system overlay")
        suite.expect(ScreenshotCapturePolicy.isPickableWindowLayer(8, ownerName: "Raycast")
                     && ScreenshotCapturePolicy.isPickableWindowLayer(25, ownerName: "Floating app")
                     && ScreenshotCapturePolicy.isPickableWindowLayer(0, ownerName: "Finder"),
                     "real floating app windows and ordinary windows remain selectable")
        suite.expect(ScreenshotCapturePolicy.isPickableWindowLayer(0, ownerName: "WindowManager")
                     && decorations.contains(17087),
                     "ordinary-layer windows retain existing decoration filtering rather than owner-wide exclusion")
        for layer in [2, 14, 19] {
            suite.expect(!ScreenshotCapturePolicy.isPickableWindowLayer(layer, ownerName: "WindowManager"),
                         "Exposé system chrome at layer \(layer) cannot intercept window selection")
        }
        suite.expect(!ScreenshotCapturePolicy.isPickableWindowLayer(20, ownerName: "Dock")
                     && !ScreenshotCapturePolicy.isPickableWindowLayer(24, ownerName: "Window Server")
                     && ScreenshotCapturePolicy.isPickableWindowLayer(26, ownerName: "Floating app")
                     && !ScreenshotCapturePolicy.isPickableWindowLayer(1001, ownerName: "Floating app")
                     && !ScreenshotCapturePolicy.isPickableWindowLayer(-1, ownerName: "Floating app"),
                     "existing system-overlay and layer-range exclusions remain enforced")
    }
}
