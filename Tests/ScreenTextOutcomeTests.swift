// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Vision

/// Production selection and line decoding with synthetic Vision/barcode replies.
/// No real screen, player, pasteboard or recognition engine is used.
enum ScreenTextOutcomeTests {
    typealias CGImage = Int
    enum BarcodeDetector {
        struct Reading: Equatable { let payload: String }
        static var result: Reading?
        static func read(_ image: Int) -> Reading? { result }
    }
    enum VisionTextRecognition {
        struct Candidate { let string: String }
        struct Observation {
            let text: String
            let boundingBox = CGRect(x: 0, y: 0, width: 1, height: 1)
            func topCandidates(_ count: Int) -> [Candidate] { [Candidate(string: text)] }
        }
        static var accurate: [Observation]?
        static var fast: [Observation]?
        static func observations(in image: Int, level: VNRequestTextRecognitionLevel,
                                 detectLanguage: Bool, languages: [String]) -> [Observation]? {
            level == .accurate ? accurate : fast
        }
    }

    static func run(_ suite: TestSuite) {
        BarcodeDetector.result = nil
        VisionTextRecognition.accurate = nil
        VisionTextRecognition.fast = []
        suite.expect(Service.outcome(for: 1, detectQRCodes: true, removeLineBreaks: false) == .unavailable,
                     "an empty fast result after accurate OCR failure cannot erase a Watch reading")
        VisionTextRecognition.accurate = []
        suite.expect(Service.outcome(for: 1, detectQRCodes: false, removeLineBreaks: false) == .empty,
                     "successful accurate recognition can establish a genuinely empty region")
        VisionTextRecognition.accurate = nil
        VisionTextRecognition.fast = [.init(text: "Still visible")]
        suite.expect(Service.outcome(for: 1, detectQRCodes: false, removeLineBreaks: false) == .text("Still visible"),
                     "a successful fast recovery preserves recognized text")
        VisionTextRecognition.fast = []
        let reading = BarcodeDetector.Reading(payload: "local-code")
        BarcodeDetector.result = reading
        suite.expect(Service.outcome(for: 1, detectQRCodes: true, removeLineBreaks: false) == .qr(reading),
                     "valid QR data survives a failed accurate request and empty fast fallback")
        VisionTextRecognition.fast = nil
        suite.expect(Service.outcome(for: 1, detectQRCodes: true, removeLineBreaks: false) == .qr(reading),
                     "valid QR data remains usable when both text requests fail")
        suite.expect(Service.outcome(for: 1, detectQRCodes: false, removeLineBreaks: false) == .unavailable,
                     "disabling QR detection cannot conceal complete OCR unavailability")
        BarcodeDetector.result = nil
    }
}
