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
            controller.prepareRecording(anchorRect: CGRect(x: -20000, y: -20000, width: 1000, height: 800),
                                        pixelSize: CGSize(width: 2000, height: 1600), immediate: false)
            controller.cameraEnabled = true
            controller.moveCamera(origin: CGPoint(x: -19700, y: -19700))
            let beforeLayout = controller.frames.snapshot.layout.frame(in: controller.pixelSize)
            let panel = NSApp.windows.first { controller.excludedWindowNumbers.contains($0.windowNumber) }
            let beforeSnap = panel?.frame
            controller.snapCameraToNearestEdge()
            suite.expect(beforeSnap != nil && panel?.frame == beforeSnap,
                         "camera snapping begins at the dragged position rather than jumping to its target")
            suite.expect(controller.frames.snapshot.layout.frame(in: controller.pixelSize) == beforeLayout,
                         "composited video begins the snap at the same dragged position as the visible PiP")
            RunLoop.main.run(until: Date().addingTimeInterval(0.12))
            let intermediate = panel?.frame
            suite.expect(intermediate != beforeSnap, "camera snap advances through intermediate frames")
            let outputFrame = controller.frames.snapshot.layout.frame(in: controller.pixelSize)
            // Native windows quantize origins to screen points; video can
            // preserve subpixel animation positions within that one point.
            suite.expectClose((intermediate?.minX ?? 0) + 20000, outputFrame.minX / 2,
                              "visible and recorded PiP share the horizontal intermediate position", tol: 1)
            suite.expectClose((intermediate?.minY ?? 0) + 20000, outputFrame.minY / 2,
                              "visible and recorded PiP share the vertical intermediate position", tol: 1)
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            suite.expect(panel?.frame != intermediate, "camera snap completes beyond the intermediate frame")
            controller.stop()
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
