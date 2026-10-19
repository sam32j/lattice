// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia
import CoreVideo

final class RecorderOverlayCompositor {
    enum Failure: Error { case invalidFrame, compositionFailed, allocationFailed }
    private lazy var context = CIContext(options: [.cacheIntermediates: false])
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero

    func image(screen: CIImage, camera: CIImage?, layout: RecorderCameraLayout,
               keyImage: CGImage?) throws -> CIImage {
        var result = screen
        let canvas = screen.extent
        if layout.isFullArea && camera == nil { throw Failure.invalidFrame }
        if let camera {
            let frame = layout.frame(in: canvas.size).offsetBy(dx: canvas.minX, dy: canvas.minY)
            guard camera.extent.width > 0, camera.extent.height > 0, !frame.isEmpty else { throw Failure.invalidFrame }
            var source = camera.transformed(by: CGAffineTransform(translationX: -camera.extent.minX, y: -camera.extent.minY))
            if layout.isFlipped {
                source = source.transformed(by: CGAffineTransform(translationX: source.extent.width, y: 0).scaledBy(x: -1, y: 1))
            }
            let scale = max(frame.width / source.extent.width, frame.height / source.extent.height)
            source = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            source = source.transformed(by: CGAffineTransform(
                translationX: frame.midX - source.extent.midX,
                y: frame.midY - source.extent.midY)).cropped(to: frame)
            if !layout.isFullArea {
                let mask = CIFilter.roundedRectangleGenerator()
                mask.extent = frame
                mask.radius = Float(layout.cornerRadius(in: frame))
                mask.color = .white
                let blend = CIFilter.blendWithAlphaMask()
                blend.inputImage = source
                blend.backgroundImage = CIImage.empty()
                blend.maskImage = mask.outputImage
                guard let masked = blend.outputImage else { throw Failure.compositionFailed }
                source = masked.cropped(to: frame)
            }
            result = source.composited(over: result)
        }
        if let keyImage {
            var keys = CIImage(cgImage: keyImage)
            let scale = min(1, canvas.width * 0.9 / keys.extent.width, canvas.height * 0.2 / keys.extent.height)
            keys = keys.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            keys = keys.transformed(by: CGAffineTransform(translationX: canvas.midX - keys.extent.width / 2,
                                                          y: canvas.minY + min(28, canvas.height * 0.05)))
            result = keys.composited(over: result)
        }
        return result.cropped(to: canvas)
    }

    /// Called on the recorder's serial writer queue. Keeps the original host
    /// clock timestamp so the writer's existing pause/audio mapping still applies.
    func sample(_ sample: CMSampleBuffer, camera: CIImage?, layout: RecorderCameraLayout,
                keyImage: CGImage?) throws -> CMSampleBuffer {
        guard camera != nil || keyImage != nil || layout.isFullArea else { return sample }
        guard let original = CMSampleBufferGetImageBuffer(sample) else { throw Failure.invalidFrame }
        let size = CGSize(width: CVPixelBufferGetWidth(original), height: CVPixelBufferGetHeight(original))
        if pool == nil || poolSize != size {
            let attributes: [String: Any] = [kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
            guard CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess
            else { throw Failure.allocationFailed }
            poolSize = size
        }
        var pixels: CVPixelBuffer?
        guard let pool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixels) == kCVReturnSuccess,
              let pixels else { throw Failure.allocationFailed }
        CVBufferPropagateAttachments(original, pixels)
        let screen = CIImage(cvPixelBuffer: original)
        let composed = try image(screen: screen, camera: camera, layout: layout, keyImage: keyImage)
        context.render(composed, to: pixels, bounds: CGRect(origin: .zero, size: size),
                       colorSpace: screen.colorSpace ?? CGColorSpaceCreateDeviceRGB())
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: pixels, formatDescriptionOut: &format) == noErr, let format
        else { throw Failure.compositionFailed }
        var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sample),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sample),
            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sample))
        var output: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: pixels, formatDescription: format, sampleTiming: &timing,
            sampleBufferOut: &output) == noErr, let output else { throw Failure.compositionFailed }
        CMPropagateAttachments(sample, destination: output)
        return output
    }
}

/// Camera and key producers publish retained frame snapshots. Only the writer
/// queue uses the compositor; UI and capture callbacks never mutate its context.
final class RecorderOverlayFrameStore: @unchecked Sendable {
    struct Snapshot {
        var generation = 0
        var camera: CIImage?
        var layout = RecorderCameraLayout()
        var keyImage: CGImage?
    }
    private let lock = NSLock()
    private var value = Snapshot()
    var snapshot: Snapshot { lock.lock(); defer { lock.unlock() }; return value }
    func setCamera(_ pixels: CVPixelBuffer?) { lock.lock(); defer { lock.unlock() }; value.camera = pixels.map { CIImage(cvPixelBuffer: $0) } }
    func setLayout(_ layout: RecorderCameraLayout) { lock.lock(); defer { lock.unlock() }; value.layout = layout }
    func setKeys(_ image: CGImage?) { lock.lock(); defer { lock.unlock() }; value.keyImage = image }
    func clear() {
        lock.lock(); defer { lock.unlock() }
        let generation = value.generation + 1
        value = Snapshot()
        value.generation = generation
    }
}
