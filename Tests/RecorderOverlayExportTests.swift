// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation
import CoreImage

enum RecorderOverlayExportTests {
    enum FixtureError: Error { case buffer, writer, reader, append }
    static func run(_ suite: TestSuite) {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            defer { done.signal() }
            do { try await check(suite) }
            catch { suite.expect(false, "recorded overlay export fixture: \(error)") }
        }
        suite.expect(done.wait(timeout: .now() + 30) == .success, "camera overlay exports and decodes within its deadline")
    }
    private static func check(_ suite: TestSuite) async throws {
        let input = try sample()
        var layout = RecorderCameraLayout()
        layout.isFullArea = true
        let compositor = RecorderOverlayCompositor()
        let camera = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 80, height: 60))
        let composed = try compositor.sample(input, camera: camera, layout: layout, keyImage: nil)
        suite.expect(CMSampleBufferGetPresentationTimeStamp(composed) == CMTime(value: 100, timescale: 1)
            && CMSampleBufferGetDuration(composed) == CMTime(value: 1, timescale: 30),
                     "composition preserves capture timestamps and duration for pause/audio synchronization")
        suite.expect((try? compositor.sample(input, camera: nil, layout: layout, keyImage: nil)) == nil,
                     "the sample path cannot bypass camera-only missing-frame protection")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("camera-overlay-\(UUID()).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        guard let writer = RecorderWriter(url: url, pixelSize: CGSize(width: 64, height: 64), frameRate: 30,
            capturesSystemAudio: false, capturesMicrophone: false, pauseClock: RecorderPauseClock()), writer.start()
        else { throw FixtureError.writer }
        writer.beginSession(at: CMTime(value: 100, timescale: 1))
        var appended = false
        for _ in 0..<2000 {
            switch writer.append(composed, kind: .video) {
            case .appended: appended = true
            case .dropped: throw FixtureError.append
            case .notReady: try await Task.sleep(nanoseconds: 1_000_000)
            }
            if appended { break }
        }
        guard appended else { writer.cancel(); throw FixtureError.append }
        let finished = await writer.finish(at: CMTime(value: 401, timescale: 4))
        suite.expect(finished, "camera-composited recording finalizes as a real video")
        guard finished else { return }
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw FixtureError.reader }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        guard reader.canAdd(output) else { throw FixtureError.reader }
        reader.add(output)
        guard reader.startReading() else { throw FixtureError.reader }
        var frames = 0
        var allCamera = true
        while let decoded = output.copyNextSampleBuffer() {
            guard let pixels = CMSampleBufferGetImageBuffer(decoded) else { throw FixtureError.reader }
            let color = RecorderOverlayCompositionTests.pixel(CIImage(cvPixelBuffer: pixels), CGPoint(x: 32, y: 32))
            allCamera = allCamera && color[0] > 200 && color[2] < 40
            frames += 1
        }
        suite.expect(reader.status == .completed && frames > 0 && allCamera,
                     "decoded recording, including the held final frame, contains camera pixels instead of desktop")
    }
    private static func sample() throws -> CMSampleBuffer {
        var pixels: CVPixelBuffer?
        guard CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &pixels) == kCVReturnSuccess,
              let pixels else { throw FixtureError.buffer }
        CIContext().render(CIImage(color: CIColor(red: 0, green: 0, blue: 1)), to: pixels,
            bounds: CGRect(x: 0, y: 0, width: 64, height: 64), colorSpace: CGColorSpaceCreateDeviceRGB())
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: pixels, formatDescriptionOut: &format) == noErr, let format else { throw FixtureError.buffer }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: 100, timescale: 1), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels,
            formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sample) == noErr,
              let sample else { throw FixtureError.buffer }
        return sample
    }
}
