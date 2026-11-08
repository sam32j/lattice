// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderPreviewModelTests {
    static func run(_ suite: TestSuite) {
        MainActor.assumeIsolated { RecorderPreviewEditTests.run(suite) }
        RecorderPreviewShortcutTests.run(suite)
        final class Loader {
            var pending: [URL: CheckedContinuation<CGImage?, Never>] = [:]
            func load(_ url: URL) async -> CGImage? {
                await withCheckedContinuation { pending[url] = $0 }
            }
        }
        func settle(_ ready: () -> Bool) {
            let deadline = Date().addingTimeInterval(1)
            while !ready(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        }
        func image(_ width: Int) -> CGImage {
            CGContext(data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        }
        let loader = Loader()
        let model = RecorderQuickPreviewModel(loadThumbnail: loader.load)
        let a = URL(fileURLWithPath: "/synthetic/a.mov"), b = URL(fileURLWithPath: "/synthetic/b.mov")
        model.show(url: a)
        settle { loader.pending[a] != nil }
        model.show(url: b, initialThumbnail: image(2))
        loader.pending.removeValue(forKey: a)?.resume(returning: image(1))
        // Allow the stale task to resume even if its loader ignored cancellation.
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        suite.expect(model.thumbnail?.width == 2, "an old thumbnail cannot replace the current video preview")
        model.show(url: a)
        settle { loader.pending[a] != nil }
        model.close()
        loader.pending.removeValue(forKey: a)?.resume(returning: image(3))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        suite.expect(model.thumbnail == nil, "closed previews cannot publish late thumbnails")
        model.sharing = true
        model.close()
        suite.expect(!model.sharing && model.sharedRecord == nil,
                     "closing a recording preview resets pending Quick Link UI state")

        let controller = (try? String(contentsOfFile:
            "Sources/Lattice/Services/Recorder/RecorderQuickPreviewController.swift",
            encoding: .utf8)) ?? ""
        let view = (try? String(contentsOfFile:
            "Sources/Lattice/UI/Recorder/RecorderQuickPreviewView.swift",
            encoding: .utf8)) ?? ""
        suite.expect(controller.contains("imageOverlay: true")
            && view.contains("private var islandPreview:")
            && view.contains(".scaledToFill()")
            && view.contains("islandVideoToolbar.padding(6)"),
            "video shares the image preview canvas without adding a control row")
        suite.expect(controller.contains("!openedFromHistory, !pointerInside")
            && controller.contains("openedFromHistory: openedFromHistory"),
            "manually reopened recordings never inherit the confirmation timeout")
        let islandPart = view.components(separatedBy: "    private var islandPreview:")
            .dropFirst().first?.components(separatedBy: "    private func islandTool(").first ?? ""
        suite.expect(islandPart.contains("thumbnailButton(symbol: \"play.fill\"")
            && !islandPart.contains("play.circle.fill")
            && islandPart.contains(".overlay(alignment: .topLeading)"),
            "recording Quick Look uses a top-left button instead of a centered play overlay")
        suite.expect(view.contains(".contentShape(Rectangle())")
            && controller.contains("sharePresenter.present(for: [url], from: content")
            && controller.contains("NotchIslandAlert.run(alert, above: owner)")
            && controller.contains("NotchService.shared.showCaptureHistory()")
            && controller.contains("owner: panel ?? NotchService.shared.presentationWindow"),
            "recording actions have full hit areas, real share anchor, elevated deletion, and Island Quick Look ownership")
        suite.expect(controller.contains("exportForSharing(")
            && controller.contains("RecordingShareService.shared.createLink(")
            && controller.contains("try FileManager.default.trashItem(at: source")
            && controller.contains("RecentCaptureService.shared.removeRecording(at: source)"),
            "video Quick Link uses validated MP4 export; Delete moves the real file to Trash")
    }
}
