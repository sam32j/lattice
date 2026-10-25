// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Vision

/// Screen OCR: the user picks an area on the app's own capture surface, the
/// text in it is recognized offline with Vision and lands on the clipboard.
/// Needs Screen Recording, requested contextually on first use.
///
/// The picking and the capture both happen here rather than through the
/// system's capture command. A separate command is judged by macOS on its own
/// standing, which on recent versions can be refused even while this app is
/// allowed, and a refused command writes no file and says nothing: the tool
/// looked dead with no crosshair, no message and nothing to fix (issue #364).
final class ScreenTextService: ObservableObject {
    static let shared = ScreenTextService()

    private var recognitionGeneration = 0

    private init() {}

    func syncWithPreferences() {
        guard AppFeature.screenOCR.isAvailable else {
            cancelSession()
            return
        }
        VisionTextRecognition.prepare()
    }

    func suspend() {
        cancelSession()
    }

    private func cancelSession() {
        recognitionGeneration += 1
    }


    func receiveUnifiedCapture(_ capture: ScreenshotSelectionController.Capture) {
        recognize(capture.image,
                  detectQRCodes: UserDefaults.standard.bool(
                    forKey: DefaultsKey.screenOCRDetectQRCodes))
    }

    /// Copies text from an image that has already been captured. Screenshot
    /// previews expose QR results separately, so this path deliberately runs
    /// text recognition even when the image also contains a code.
    func copyText(from image: CGImage) {
        recognize(image, detectQRCodes: UserDefaults.standard.bool(forKey: DefaultsKey.screenOCRDetectQRCodes))
    }

    /// What a captured region turned out to hold.
    enum Outcome: Equatable {
        case qr(BarcodeDetector.Reading)
        case text(String)
        case both(BarcodeDetector.Reading, text: String)
        case empty
        case unavailable

        static func readingPayload(from reading: BarcodeDetector.Reading) -> String {
            reading.payload
        }
    }

    private func recognize(_ image: CGImage, detectQRCodes: Bool) {
        guard AppFeature.screenOCR.isAvailable else { return }
        recognitionGeneration += 1
        let generation = recognitionGeneration
        let pasteboardChangeCount = NSPasteboard.general.changeCount
        let removeLineBreaks = UserDefaults.standard.bool(forKey: DefaultsKey.screenOCRRemoveLineBreaks)
        let fallbackLanguages = MediaSupport.recognitionLanguages(for: L10n.shared.language.rawValue)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = ScreenTextService.outcome(for: ScreenTextService.recognitionImage(image),
                                                    detectQRCodes: detectQRCodes,
                                                    removeLineBreaks: removeLineBreaks,
                                                    fallbackLanguages: fallbackLanguages)
            DispatchQueue.main.async { [weak self] in
                // A later copy belongs to the user, even if this recognition
                // is still the latest OCR request. Never replace it with a
                // result from an earlier capture.
                guard self?.recognitionGeneration == generation,
                      AppFeature.screenOCR.isAvailable,
                      NSPasteboard.general.changeCount == pasteboardChangeCount else { return }
                let strings = L10n.shared.s
                switch outcome {
                case .qr(let reading):
                    let payload = Outcome.readingPayload(from: reading)
                    Self.copyToPasteboard(payload)
                    QuickToolHUD.show(icon: "text.viewfinder", message: strings.ocrCopied)
                case .text(let text):
                    Self.copyToPasteboard(text)
                    QuickToolHUD.show(icon: "text.viewfinder", message: strings.ocrCopied)
                case .both(let reading, let text):
                    let payload = Outcome.readingPayload(from: reading)
                    let combined = text.contains(payload) ? text : "\(text)\n\n\(payload)"
                    Self.copyToPasteboard(combined)
                    QuickToolHUD.show(icon: "text.viewfinder", message: strings.ocrCopied)
                case .empty:
                    QuickToolHUD.show(icon: "text.viewfinder", message: strings.ocrNoText)
                case .unavailable:
                    QuickToolHUD.show(icon: "text.viewfinder",
                        message: OCRRecoveryCopy.unavailable(language: L10n.shared.language.rawValue))
                }
            }
        }
    }

    /// A capture can run to tens of megapixels, like a long scrolling
    /// capture in a screenshot preview or a large area on an 8K display.
    /// Past the bound the clipboard history's Copy text uses, either is
    /// scaled down here, off the main thread, before Vision reads it.
    private static func recognitionImage(_ image: CGImage) -> CGImage {
        guard let size = ClipboardImageRecognition.scaledSize(width: image.width, height: image.height),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil,
                                      width: size.width,
                                      height: size.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return context.makeImage() ?? image
    }

    /// Decides what a captured region holds. Scans for both QR codes and text:
    /// when both are found, both are recognized. Pure enough to exercise directly on a known image.
    static func outcome(for image: CGImage,
                        detectQRCodes: Bool,
                        removeLineBreaks: Bool,
                        fallbackLanguages: [String] = ["en-US"]) -> Outcome {
        let reading = detectQRCodes ? BarcodeDetector.read(image) : nil

        let accurate = recognizedLines(in: image, level: .accurate,
            automaticallyDetectLanguage: true, preferredLanguages: fallbackLanguages)
        var lines = accurate ?? []
        if lines.isEmpty {
            let fast = recognizedLines(in: image, level: .fast,
                automaticallyDetectLanguage: false, preferredLanguages: fallbackLanguages)
            if accurate == nil && fast == nil && reading == nil { return .unavailable }
            lines = fast ?? []
        }
        let text = QuickToolsSupport.joinedRecognizedText(lines,
                                                         removingLineBreaks: removeLineBreaks)
        if let reading, !text.isEmpty {
            return .both(reading, text: text)
        } else if let reading {
            return .qr(reading)
        } else if !text.isEmpty {
            return .text(text)
        } else {
            return .empty
        }
    }

    private static func recognizedLines(
        in image: CGImage,
        level: VNRequestTextRecognitionLevel,
        automaticallyDetectLanguage: Bool,
        preferredLanguages: [String] = []
    ) -> [QuickToolsSupport.RecognizedLine]? {
        guard let observations = VisionTextRecognition.observations(in: image, level: level,
            detectLanguage: automaticallyDetectLanguage, languages: preferredLanguages) else { return nil }
        return observations.compactMap { observation -> QuickToolsSupport.RecognizedLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return QuickToolsSupport.RecognizedLine(text: candidate.string,
                                                    x: observation.boundingBox.minX,
                                                    y: observation.boundingBox.midY)
        }
    }

    private static let successSound = NSSound(contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/acknowledgment_sent.caf", byReference: true)

    static func playSuccessSound() {
        if let successSound {
            successSound.stop()
            successSound.play()
        } else {
            NSSound.beep()
        }
    }

    static func copyToPasteboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareLatticeSource()
        pasteboard.setString(value, forType: .string)
        playSuccessSound()
    }
}

