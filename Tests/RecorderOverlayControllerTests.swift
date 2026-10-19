// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderOverlayControllerTests {
    static func run(_ suite: TestSuite) {
        MainActor.assumeIsolated {
            let controller = RecorderOverlayController(source: RecorderCameraCaptureTests.Source())
            defer { controller.stop() }
            suite.expect(!controller.cameraEnabled && !controller.keysEnabled,
                         "camera and keystroke recording require an explicit opt-in")
            controller.updateRegion(anchorRect: CGRect(x: 100, y: 100, width: 50, height: 40),
                                    pixelSize: CGSize(width: 100, height: 80))
            suite.expect(!controller.layout.isAvailable(.medium, in: controller.pixelSize),
                         "camera size menu follows selection pixels rather than screen points")
            controller.selectedCameraID = "removed"
            controller.cameraEnabled = true
            let deadline = Date().addingTimeInterval(3)
            while controller.errorMessage == nil, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            suite.expect(controller.errorMessage != nil && !controller.cameraEnabled,
                         "an unavailable input is visible and never presented as an enabled camera")
            controller.dismissError()
            suite.expect(controller.errorMessage == nil, "camera error acknowledgement clears its alert state")
        }
    }
}
