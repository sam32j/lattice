// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreML
import CoreText
import OSLog
import Vision

/// One screenshot text engine, shared by copy-text and editor word detection.
/// CPU-backed requests avoid graphics-pipeline startup. Warm-up never reads
/// the screen or clipboard; real requests wait behind it
/// rather than being dropped while Vision loads its models.
enum VisionTextRecognition {
    private static let queue = DispatchQueue(label: "io.github.sam32j.lattice.vision-text", qos: .userInitiated)
    private static let warmupLock = NSLock()
    private static var scheduledWarmup = false
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? DownstreamIdentity.bundleID,
                                    category: "text-recognition")

    static func prepare() {
        warmupLock.lock()
        let shouldSchedule = !scheduledWarmup
        scheduledWarmup = true
        warmupLock.unlock()
        guard shouldSchedule else { return }
        queue.async {
            guard let image = warmupImage() else { return }
            _ = perform(image, level: .accurate, detectLanguage: false, languages: ["en-US"])
        }
    }

    static func observations(in image: CGImage, level: VNRequestTextRecognitionLevel = .accurate,
                             detectLanguage: Bool = true, languages: [String] = []) -> [VNRecognizedTextObservation]? {
        queue.sync { try? perform(image, level: level, detectLanguage: detectLanguage, languages: languages).get() }
    }

    private static func perform(_ image: CGImage, level: VNRequestTextRecognitionLevel,
                                detectLanguage: Bool, languages: [String]) -> Result<[VNRecognizedTextObservation], Error> {
        TextRecognitionRecovery.perform(retryable: { error in
            let error = error as NSError
            return error.domain == VNErrorDomain && [VNErrorCode.internalError.rawValue,
                VNErrorCode.operationFailed.rawValue, VNErrorCode.outOfMemory.rawValue].contains(error.code)
        }, pause: { Thread.sleep(forTimeInterval: $0) }) { _ in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = level
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = detectLanguage
            if !languages.isEmpty {
                let supported = try request.supportedRecognitionLanguages()
                let selected = languages.filter { supported.contains($0) }
                if !selected.isEmpty { request.recognitionLanguages = selected }
            }
            for (stage, devices) in try request.supportedComputeStageDevices {
                if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                return request.results ?? []
            } catch {
                let failure = error as NSError
                log.notice("Text request unavailable: domain=\(failure.domain, privacy: .public) code=\(failure.code)")
                throw error
            }
        }
    }

    private static func warmupImage() -> CGImage? {
        guard let context = CGContext(data: nil, width: 320, height: 64, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 320, height: 64))
        let text = NSAttributedString(string: "Lattice", attributes: [
            .font: NSFont.systemFont(ofSize: 32), .foregroundColor: NSColor.black])
        context.textPosition = CGPoint(x: 12, y: 16)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
        return context.makeImage()
    }
}
