// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation

enum RecorderCameraCaptureTests {
    /// The hardware capture boundary is replaced, never an internal renderer.
    final class Source: RecorderCameraSource, @unchecked Sendable {
        var request: RecorderCameraRequest?
        var frame: ((CVPixelBuffer) -> Void)?
        var failure: ((String) -> Void)?
        var stopped = false
        func start(deviceID: String?, request: RecorderCameraRequest,
                   onFrame: @escaping (CVPixelBuffer) -> Void,
                   onFailure: @escaping (String) -> Void) async throws {
            if deviceID == "removed" { throw NSError(domain: "fixture-camera", code: 1) }
            self.request = request
            frame = onFrame
            failure = onFailure
        }
        func stop(request: RecorderCameraRequest) async {
            if self.request === request { stopped = true }
        }
    }
    static func run(_ suite: TestSuite) {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            let store = RecorderOverlayFrameStore()
            let source = Source()
            let capture = RecorderCameraCapture(source: source, frames: store)
            let started = await capture.start(deviceID: "fixture").value
            suite.expect(started, "camera starts through the selected input boundary")
            var pixels: CVPixelBuffer?
            CVPixelBufferCreate(nil, 32, 32, kCVPixelFormatType_32BGRA, nil, &pixels)
            guard let pixels else { suite.expect(false, "camera fixture pixels"); done.signal(); return }
            source.frame?(pixels)
            suite.expect(store.snapshot.camera != nil, "active camera frames reach recording composition")
            let oldFrame = source.frame
            let oldFailure = source.failure
            let replaced = await capture.start(deviceID: "replacement").value
            suite.expect(replaced && !capture.hasCurrentFrame,
                         "changing input never treats a retained previous-camera frame as a ready new camera")
            oldFrame?(pixels)
            suite.expect(!capture.hasCurrentFrame, "a queued old-camera callback cannot become a new-source frame")
            source.frame?(pixels)
            oldFailure?("stale source failure")
            suite.expect(capture.hasCurrentFrame && store.snapshot.camera != nil,
                         "an old source's delayed failure cannot clear the replacement camera")
            await capture.stop().value
            suite.expect(source.stopped && store.snapshot.camera == nil, "stopping releases camera capture and its last frame")
            source.frame?(pixels)
            suite.expect(store.snapshot.camera == nil, "late camera callbacks cannot revive a stopped overlay")
            let missing = await capture.start(deviceID: "removed").value
            suite.expect(!missing && store.snapshot.camera == nil, "a removed camera is a failed start, not a successful empty recording")
            done.signal()
        }
        suite.expect(done.wait(timeout: .now() + 10) == .success, "camera boundary checks finish without using physical hardware")
    }
}
