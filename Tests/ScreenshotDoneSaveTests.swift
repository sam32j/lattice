// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// The production Done action runs against a controlled persistence boundary.
enum ScreenshotDoneSaveTests {
    struct Export { let image: CGImage; let scale: CGFloat }
    final class Model {
        let baseImage: CGImage
        var editingTextID: UUID?
        var annotations: [ScreenshotSupport.Annotation] = []
        var backdropStyle = ScreenshotSupport.BackdropStyle()
        var watermarkStyle = ScreenshotSupport.WatermarkStyle()
        var annotationShadowsEnabled = false
        var markedClean = false
        var usedDownscale: Bool?
        init() {
            baseImage = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        }
        func exportImage(withBackdrop: Bool, downscaleTo1x: Bool? = nil) -> Export? {
            usedDownscale = downscaleTo1x
            return .init(image: baseImage, scale: downscaleTo1x == false ? 2 : 1)
        }
        func markExported() { markedClean = true }
    }
    final class Window {
        var firstResponder: Any?
        var closed = false
        func close() { closed = true }
    }
    final class Pin {
        func updateImage(_ image: CGImage, baseImage: CGImage, annotations: [ScreenshotSupport.Annotation]) {}
        func showPin(orderFront: Bool) {}
    }
    enum ScreenshotPinController {
        static let shared = Bridge()
        final class Bridge {
            var lastScale: CGFloat?
            func findPin(for id: UUID) -> Pin? { nil }
            func pin(image: CGImage, scale: CGFloat, baseImage: CGImage,
                     annotations: [ScreenshotSupport.Annotation], captureID: UUID) -> Pin {
                lastScale = scale
                return Pin()
            }
        }
    }
    enum NSSound { static func beep() {} }
    enum RecentCaptureService {
        static let shared = Store()
        final class Store {
            var completion: ((Bool) -> Void)?
            func saveEditedCapture(id: UUID, renderedImage: CGImage, baseImage: CGImage, scale: CGFloat,
                                   annotations: [ScreenshotSupport.Annotation], completion: @escaping (Bool) -> Void) {
                self.completion = completion
            }
        }
    }
    struct Capture { let id = UUID() }
    class State {
        let model = Model()
        let capture = Capture()
        var window: Window? = Window()
        var originatingPin: Pin?
        var doneSaveInFlight = false
    }
    static func run(_ suite: TestSuite) {
        let pinning = Controller()
        pinning.pin()
        suite.expect(pinning.model.usedDownscale == false && ScreenshotPinController.shared.lastScale == 2
                     && pinning.originatingPin != nil,
                     "direct Pin preserves source scale and editable annotations even when exports use 1x")
        let failed = Controller()
        failed.done()
        suite.expect(failed.model.usedDownscale == false,
                     "Done stores source-resolution edits regardless of the final-output downscale preference")
        suite.expect(failed.window?.closed == false && !failed.model.markedClean,
                     "Done waits for persistence before closing or marking edits clean")
        RecentCaptureService.shared.completion?(false)
        suite.expect(failed.window?.closed == false && !failed.model.markedClean && !failed.doneSaveInFlight,
                     "a failed Done save preserves editable unsaved work and permits retry")
        failed.done()
        RecentCaptureService.shared.completion?(true)
        suite.expect(failed.window?.closed == true && failed.model.markedClean,
                     "a successful retry completes Done")
        let changed = Controller()
        changed.done()
        changed.model.annotations.append(.init(tool: .text, text: "A later edit"))
        RecentCaptureService.shared.completion?(true)
        suite.expect(changed.window?.closed == false && !changed.model.markedClean,
                     "a late save completion cannot discard edits made while saving")
        RecentCaptureService.shared.completion = nil
    }
}
