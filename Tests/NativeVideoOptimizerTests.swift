import AppKit
import AVFoundation

enum NativeVideoOptimizerTests {
    static func run(_ suite: TestSuite, folder: URL) throws {
        let input = folder.appendingPathComponent("portrait.mov")
        let writer = try AVAssetWriter(outputURL: input, fileType: .mov)
        let track = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1920, AVVideoHeightKey: 1080,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 3_000_000, AVVideoMaxKeyFrameIntervalKey: 1]
        ])
        track.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: track, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1920, kCVPixelBufferHeightKey as String: 1080
        ])
        writer.add(track)
        guard writer.startWriting() else { throw writer.error ?? NativeMediaError.invalidOutput }
        writer.startSession(atSourceTime: .zero)
        let deadline = Date().addingTimeInterval(10)
        for index in 0..<6 {
            while !track.isReadyForMoreMediaData && Date() < deadline { Thread.sleep(forTimeInterval: 0.001) }
            guard track.isReadyForMoreMediaData else { throw NativeMediaError.timedOut }
            var pixel: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel) == kCVReturnSuccess,
                  let pixel else { throw NativeMediaError.invalidOutput }
            CVPixelBufferLockBaseAddress(pixel, [])
            let data = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pixel)
            for y in 0..<1080 { for x in 0..<1920 {
                let offset = y * stride + x * 4
                data[offset] = UInt8(x % 256); data[offset + 1] = UInt8(y % 256)
                data[offset + 2] = UInt8(index * 8); data[offset + 3] = 255
            } }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(index), timescale: 6)) else {
                throw writer.error ?? NativeMediaError.invalidOutput
            }
        }
        track.markAsFinished()
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        guard finished.wait(timeout: .now() + 10) == .success, writer.status == .completed else {
            throw writer.error ?? NativeMediaError.timedOut
        }
        let original = try Data(contentsOf: input)
        let withAudio = try addingAudio(to: input, folder: folder)
        for stronger in [false, true] {
            let output = try NativeVideoOptimizer().optimize(withAudio, aggressive: stronger, directory: folder)
            let result = AVURLAsset(url: output)
            let outputTrack = result.tracks(withMediaType: .video).first!
            let bounds = CGRect(origin: .zero, size: outputTrack.naturalSize).applying(outputTrack.preferredTransform).standardized
            suite.expect(result.isPlayable && abs(result.duration.seconds - 1) < 0.1,
                         "native HEVC export is playable and preserves duration in both compression modes")
            suite.expect(abs(bounds.width - (stronger ? 720 : 1080)) < 1 && abs(bounds.height - (stronger ? 1280 : 1920)) < 1,
                         "native export preserves portrait orientation and applies the requested resolution cap")
            suite.expect(!result.tracks(withMediaType: .audio).isEmpty, "native video compression retains the audio track")
        }
        suite.expect(try Data(contentsOf: input) == original, "native video export preserves original bytes")
        let cancelling = NativeVideoOptimizer()
        let started = DispatchSemaphore(value: 0), done = DispatchSemaphore(value: 0)
        let cancellation = CancellationResult()
        DispatchQueue.global().async {
            defer { done.signal() }
            started.signal()
            do { _ = try cancelling.optimize(withAudio, aggressive: true, directory: folder) }
            catch is CancellationError { cancellation.record() }
            catch { }
        }
        _ = started.wait(timeout: .now() + 2)
        Thread.sleep(forTimeInterval: 0.03)
        cancelling.cancel()
        suite.expect(done.wait(timeout: .now() + 10) == .success && cancellation.wasCancelled,
                     "cancelling a real native video operation finishes promptly as cancellation")
    }
    private final class CancellationResult: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        func record() { lock.lock(); value = true; lock.unlock() }
        var wasCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
    }
    private static func addingAudio(to video: URL, folder: URL) throws -> URL {
        let sound = folder.appendingPathComponent("tone.caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
        buffer.frameLength = 48000
        for index in 0..<48000 { buffer.floatChannelData![0][index] = Float(sin(Double(index) * 0.05) * 0.1) }
        do { let file = try AVAudioFile(forWriting: sound, settings: format.settings); try file.write(from: buffer) }
        let videoAsset = AVURLAsset(url: video), audioAsset = AVURLAsset(url: sound)
        let composition = AVMutableComposition()
        let sourceVideo = videoAsset.tracks(withMediaType: .video)[0]
        let target = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let range = CMTimeRange(start: .zero, duration: videoAsset.duration)
        try target.insertTimeRange(range, of: sourceVideo, at: .zero)
        target.preferredTransform = sourceVideo.preferredTransform
        let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try audio.insertTimeRange(range, of: audioAsset.tracks(withMediaType: .audio)[0], at: .zero)
        let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)!
        let output = folder.appendingPathComponent("portrait-with-audio.mov")
        export.outputURL = output; export.outputFileType = .mov
        let done = DispatchSemaphore(value: 0)
        export.exportAsynchronously { done.signal() }
        guard done.wait(timeout: .now() + 10) == .success, export.status == .completed else {
            throw export.error ?? NativeMediaError.invalidOutput
        }
        return output
    }
}
