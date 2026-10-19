// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderOverlayControllerTests {
    static func run(_ suite: TestSuite) {
        MainActor.assumeIsolated {
            let source = RecorderCameraCaptureTests.Source()
            let controller = RecorderOverlayController(source: source)
            defer { controller.stop() }
            suite.expect(!controller.cameraEnabled && !controller.keysEnabled,
                         "camera and keystroke recording require an explicit opt-in")
            controller.cameraEnabled = true
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            suite.expect(source.request == nil && controller.excludedWindowNumbers.isEmpty,
                         "arming a camera before area selection starts no capture session or PiP")
            controller.stop()
            controller.updateRegion(anchorRect: CGRect(x: 100, y: 100, width: 50, height: 40),
                                    pixelSize: CGSize(width: 100, height: 80))
            controller.layout.shape = .square
            suite.expectClose(controller.layout.cornerRadius(in: CGRect(x: 0, y: 0, width: 192, height: 192)), 40,
                              "twenty-point PiP corners become forty output pixels on Retina")
            suite.expect(!controller.layout.isAvailable(.medium, in: controller.pixelSize),
                         "camera size menu follows selection pixels rather than screen points")
            controller.selectedCameraID = "removed"
            controller.prepareRecording(anchorRect: CGRect(x: 100, y: 100, width: 50, height: 40),
                                        pixelSize: CGSize(width: 100, height: 80), immediate: false)
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
