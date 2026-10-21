// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation

/// Opens independent editor drafts. Never changes default file associations
/// or writes edits back to the user's input file.
final class MediaEditorFileOpener {
    static let shared = MediaEditorFileOpener()
    private var ready = false
    private var pending: [URL] = []

    func finishLaunching() {
        ready = true
        let urls = pending
        pending.removeAll()
        if !urls.isEmpty { open(urls) }
    }

    func canOpen(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { url in
            guard let kind = MediaEditorFileSupport.kind(for: url) else { return false }
            return enabled(kind)
        }
    }

    @discardableResult
    func open(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        guard ready else { pending.append(contentsOf: urls); return true }
        for input in urls {
            let url = input.resolvingSymlinksInPath()
            guard let kind = MediaEditorFileSupport.kind(for: url) else {
                fail(url, error: CocoaError(.fileReadUnsupportedScheme)); continue
            }
            guard enabled(kind) else {
                let name = kind == .image ? FeatureStrings.screenshot(L10n.shared.language).pageTitle
                    : FeatureStrings.recorder(L10n.shared.language).pageTitle
                fail(url, message: String(format: MediaEditorFileStrings.enableFeature, name))
                continue
            }
            let scoped = url.startAccessingSecurityScopedResource()
            Task { @MainActor in
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    switch kind {
                    case .image:
                        let capture = await Task.detached(priority: .userInitiated) {
                            NSImage(contentsOf: url).flatMap { ScreenshotService.imageCapture(from: $0) }
                        }.value
                        guard let capture else { throw CocoaError(.fileReadCorruptFile) }
                        guard self.enabled(kind) else { return }
                        appDelegate()?.closePopover()
                        NotchService.shared.perform {
                            MediaEditorFileSupport.presentIfEnabled(self.enabled(kind), present: {
                                ScreenshotService.shared.openEditor(with: capture)
                                return true
                            })
                        }
                    case .video:
                        let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)
                        guard !tracks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                        guard self.enabled(kind) else { return }
                        let take = await Task.detached(priority: .userInitiated) {
                            RecorderTakeStore.shared.importVideo(at: url)
                        }.value
                        guard let take else { throw CocoaError(.fileReadUnknown) }
                        guard self.enabled(kind) else { RecorderTakeStore.shared.delete(take); return }
                        appDelegate()?.closePopover()
                        NotchService.shared.perform {
                            MediaEditorFileSupport.presentIfEnabled(self.enabled(kind), present: {
                                ScreenRecorderService.shared.openEditor(with: take, preservedRecordingURL: url)
                            }, discard: { RecorderTakeStore.shared.delete(take) })
                        }
                    }
                } catch { self.fail(url, error: error) }
            }
        }
        return true
    }

    private func enabled(_ kind: MediaEditorFileSupport.Kind) -> Bool {
        MediaEditorFileSupport.isEnabled(kind, image: AppFeature.screenshot.isAvailable,
                                          video: AppFeature.screenRecorder.isAvailable)
    }

    private func fail(_ url: URL, error: Error) { fail(url, message: error.localizedDescription) }
    private func fail(_ url: URL, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = url.lastPathComponent
        alert.informativeText = message
        _ = NotchIslandAlert.run(alert, above: NSApp.keyWindow)
    }
}
