// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderOverlayTests {
    static func run(_ suite: TestSuite) {
        RecorderOverlayCompositionTests.run(suite)
        RecorderOverlayExportTests.run(suite)
        RecorderCameraCaptureTests.run(suite)
        RecorderKeystrokeTests.run(suite)
        RecorderOverlayControllerTests.run(suite)
        RecorderIndicatorLayoutTests.run(suite)
        var layout = RecorderCameraLayout()
        let tiny = CGSize(width: 100, height: 80)
        let frame = layout.frame(in: tiny)
        suite.expectClose(frame.width, 73.6, "small camera shrinks to fit a tiny selection", tol: 0.01)
        suite.expect(CGRect(origin: .zero, size: tiny).contains(frame), "camera never extends beyond its selection")
        suite.expect(!layout.isAvailable(.medium, in: tiny) && !layout.isAvailable(.big, in: tiny),
                     "medium and big are disabled when only a reduced small camera fits")
        let regular = CGSize(width: 1200, height: 800)
        suite.expectClose(layout.frame(in: regular).width, 320, "medium is the default camera size")
        layout.size = .big
        let big = layout.frame(in: regular)
        suite.expect(max(big.width, big.height) <= 500, "big PiP never exceeds five hundred output pixels")
        layout.shape = .vertical
        let vertical = layout.frame(in: regular)
        suite.expectClose(vertical.height / vertical.width, 1.47, "vertical camera mask uses the requested aspect ratio")
        let previous = layout.frame(in: regular)
        layout.isFullArea = true
        suite.expect(layout.frame(in: regular) == CGRect(origin: .zero, size: regular),
                     "full-area camera fills the selection rather than obeying the PiP cap")
        layout.isFullArea = false
        suite.expect(layout.frame(in: regular) == previous, "leaving full-area mode restores the PiP layout")
        layout.place(origin: CGPoint(x: -200, y: 3000), in: regular)
        suite.expect(CGRect(origin: .zero, size: regular).contains(layout.frame(in: regular)),
                     "dragging a PiP past an edge keeps it inside the selection")
        var magnetic = RecorderCameraLayout()
        magnetic.size = .small
        magnetic.place(origin: CGPoint(x: 20, y: 20), in: regular)
        suite.expect(magnetic.frame(in: regular).minX > 12 && magnetic.frame(in: regular).minX < 20,
                     "edge attraction is gradual rather than an abrupt full-distance jump")
    }
}
