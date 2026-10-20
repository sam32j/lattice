// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Carbon.HIToolbox
import ImageIO
import SwiftUI

/// A bounded, on-demand list of captures. Screenshots live in this cache so
/// copy-only captures can return after their preview closes. Recordings keep
/// only their file path and a small thumbnail, never a second video copy.
final class RecentCaptureService: ObservableObject {
    static let shared = RecentCaptureService()

    @Published private(set) var entries: [RecentCaptureEntry] = []
    @Published private(set) var shortcutRegistrationFailed = false

    private let manager = FileManager.default
    private let hotkey = QuickToolHotkey(id: 21)
    private let queue = DispatchQueue(label: "com.vorssaint.utils.recent-captures",
                                      qos: .utility)
    private let generationLock = NSLock()
    private let thumbnailCache = NSCache<NSString, NSImage>()
    private lazy var store = RecentCaptureStore(directoryURL: capturesRoot,
                                                thumbnailDirectoryURL: thumbnailRoot)
    private var clearGeneration = 0
    private var panel: NSPanel?
    private var panelKeyMonitor: Any?
    private var panelLocalClickMonitor: Any?
    private var panelGlobalClickMonitor: Any?
    private var panelActivationObserver: NSObjectProtocol?

    private init() {
        thumbnailCache.countLimit = ScreenshotSupport.recentCaptureLimit
        hotkey.onPress = { [weak self] in self?.showHistoryWindow() }
        reload()
    }

    func syncWithPreferences() {
        let available = AppFeature.screenshot.isAvailable || AppFeature.screenRecorder.isAvailable
        let enabled = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.recentCapturesShortcutEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.recentCapturesShortcut,
                                            fallback: .recentCapturesDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.recentCapturesShortcut)
        if !available { hideHistoryWindow() }
    }

    func suspend() {
        hotkey.unregister()
        hideHistoryWindow()
    }

    // MARK: - History palette

    func showHistoryWindow() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.showHistoryWindow() }
            return
        }
        guard AppFeature.screenshot.isAvailable || AppFeature.screenRecorder.isAvailable else {
            return
        }
        let anchor = NSApp.keyWindow?.isVisible == true ? NSApp.keyWindow : nil
        let panel = ensurePanel()
        reload()
        position(panel, over: anchor)
        installPanelMonitors(for: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hideHistoryWindow() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.hideHistoryWindow() }
            return
        }
        removePanelMonitors()
        panel?.orderOut(nil)
    }

    private final class KeyableHistoryPanel: OverlayPanel {
        override var canBecomeKey: Bool { true }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = KeyableHistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 468, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.title = FeatureStrings.recentCaptures(L10n.shared.language).title
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        // The palette is summoned from other apps. A panel that hides on deactivate
        // stays off screen until this app activates, so it would appear late.
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingController(rootView: RecentCapturesWindowView(
            onClose: { [weak self] in self?.hideHistoryWindow() }))
        host.sizingOptions = .preferredContentSize
        panel.contentViewController = host
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, over anchor: NSWindow?) {
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let size = panel.contentViewController?.view.fittingSize
            ?? NSSize(width: 468, height: 360)
        let screen = anchor?.screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        let center = anchor.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
            ?? CGPoint(x: screen.midX, y: screen.midY)
        let x = min(max(center.x - size.width / 2, screen.minX + 16),
                    screen.maxX - size.width - 16)
        let y = min(max(center.y - size.height / 2, screen.minY + 16),
                    screen.maxY - size.height - 16)
        panel.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: size),
                       display: true,
                       animate: false)
    }

    private func refreshPanelLayout() {
        guard let panel, panel.isVisible else { return }
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let size = panel.contentViewController?.view.fittingSize ?? panel.frame.size
        let screen = panel.screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        var frame = panel.frame
        frame.origin.y = min(max(frame.maxY - size.height, screen.minY + 16),
                             screen.maxY - size.height - 16)
        frame.origin.x = min(max(frame.origin.x, screen.minX + 16),
                             screen.maxX - size.width - 16)
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
    }

    private func installPanelMonitors(for panel: NSPanel) {
        removePanelMonitors()
        panelKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self, weak panel] event in
            guard event.window === panel else { return event }
            if Int(event.keyCode) == kVK_Escape {
                self?.hideHistoryWindow()
                return nil
            }
            return event
        }
        panelLocalClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] event in
                if event.window !== panel { self?.hideHistoryWindow() }
                return event
            }
        panelGlobalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.hideHistoryWindow()
            }
        panelActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                      app.bundleIdentifier != Bundle.main.bundleIdentifier,
                      app.bundleIdentifier != AssistiveKeyboard.bundleID
                else { return }
                self?.hideHistoryWindow()
            }
    }

    private func removePanelMonitors() {
        if let panelKeyMonitor { NSEvent.removeMonitor(panelKeyMonitor) }
        if let panelLocalClickMonitor { NSEvent.removeMonitor(panelLocalClickMonitor) }
        if let panelGlobalClickMonitor { NSEvent.removeMonitor(panelGlobalClickMonitor) }
        if let panelActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(panelActivationObserver)
        }
        panelKeyMonitor = nil
        panelLocalClickMonitor = nil
        panelGlobalClickMonitor = nil
        panelActivationObserver = nil
    }

    private var capturesRoot: URL? {
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return base
            .appendingPathComponent("io.github.sam32j.lattice", isDirectory: true)
            .appendingPathComponent("RecentCaptures", isDirectory: true)
    }

    private var thumbnailRoot: URL? {
        guard let base = manager.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        return base
            .appendingPathComponent("io.github.sam32j.lattice", isDirectory: true)
            .appendingPathComponent("RecentCaptures", isDirectory: true)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func reload() {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.store.loadIfNeeded() else { return }
            self.pruneMissingEntries()
            self.store.persist()
            self.publish()
        }
    }

    func recordScreenshot(_ capture: ScreenshotSelectionController.Capture) {
        let id = capture.id
        let createdAt = Date()
        let day = Self.dayFormatter.string(from: createdAt)
        let screenshotName = "\(day)/\(id.uuidString).png"
        let thumbnailName = "\(id.uuidString)-thumbnail.png"
        let entry = RecentCaptureEntry(
            id: id,
            kind: .screenshot,
            createdAt: createdAt,
            screenshotName: screenshotName,
            recordingPath: nil,
            thumbnailName: thumbnailName,
            scale: Double(capture.scale),
            anchorX: Double(capture.anchorRect.origin.x),
            anchorY: Double(capture.anchorRect.origin.y),
            anchorWidth: Double(capture.anchorRect.width),
            anchorHeight: Double(capture.anchorRect.height))
        let image = capture.image
        let scale = capture.scale

        queue.async { [weak self] in
            guard let self, let root = self.capturesRoot else { return }
            guard self.store.loadIfNeeded() else { return }
            do {
                guard let full = ScreenshotRenderer.pngData(from: image, scale: scale),
                      let smallImage = Self.thumbnail(from: image),
                      let small = ScreenshotRenderer.pngData(from: smallImage, scale: 1)
                else { return }
                try RecentCaptureStore.write(full, to: root.appendingPathComponent(screenshotName))
                let baseName = "\(day)/\(id.uuidString)-base.png"
                try? RecentCaptureStore.write(full, to: root.appendingPathComponent(baseName))
                if !capture.annotations.isEmpty,
                   let annoData = try? JSONEncoder().encode(capture.annotations) {
                    let annoName = "\(day)/\(id.uuidString)-annotations.json"
                    try? RecentCaptureStore.write(annoData, to: root.appendingPathComponent(annoName))
                }
                if let storeRoot = self.thumbnailRoot {
                    do {
                        try RecentCaptureStore.write(small, to: storeRoot.appendingPathComponent(thumbnailName))
                    } catch {
                        try? self.manager.removeItem(at: root.appendingPathComponent(screenshotName))
                        try? self.manager.removeItem(at: storeRoot.appendingPathComponent(thumbnailName))
                        throw error
                    }
                }
                self.prepend(entry)
            } catch {
                return
            }
        }
    }

    func saveEditedCapture(
        id: UUID,
        renderedImage: CGImage,
        baseImage: CGImage,
        scale: CGFloat,
        annotations: [ScreenshotSupport.Annotation]
    ) {
        queue.async { [weak self] in
            guard let self, let root = self.capturesRoot else { return }
            guard self.store.loadIfNeeded() else { return }

            let screenshotName: String
            let thumbnailName: String
            let day: String
            let entry: RecentCaptureEntry

            if let existing = self.store.entries.first(where: { $0.id == id }) {
                entry = existing
                screenshotName = existing.screenshotName ?? "\(Self.dayFormatter.string(from: existing.createdAt))/\(id.uuidString).png"
                thumbnailName = existing.thumbnailName ?? "\(id.uuidString)-thumbnail.png"
                let parts = screenshotName.split(separator: "/")
                day = parts.count > 1 ? String(parts[0]) : Self.dayFormatter.string(from: existing.createdAt)
            } else {
                let createdAt = Date()
                day = Self.dayFormatter.string(from: createdAt)
                screenshotName = "\(day)/\(id.uuidString).png"
                thumbnailName = "\(id.uuidString)-thumbnail.png"
                entry = RecentCaptureEntry(
                    id: id,
                    kind: .screenshot,
                    createdAt: createdAt,
                    screenshotName: screenshotName,
                    recordingPath: nil,
                    thumbnailName: thumbnailName,
                    scale: Double(scale)
                )
            }

            do {
                guard let renderedData = ScreenshotRenderer.pngData(from: renderedImage, scale: scale),
                      let baseData = ScreenshotRenderer.pngData(from: baseImage, scale: scale),
                      let smallImage = Self.thumbnail(from: renderedImage),
                      let smallData = ScreenshotRenderer.pngData(from: smallImage, scale: 1)
                else { return }

                let baseName = "\(day)/\(id.uuidString)-base.png"
                try RecentCaptureStore.write(baseData, to: root.appendingPathComponent(baseName))
                try RecentCaptureStore.write(renderedData, to: root.appendingPathComponent(screenshotName))

                if let storeRoot = self.thumbnailRoot {
                    try? RecentCaptureStore.write(smallData, to: storeRoot.appendingPathComponent(thumbnailName))
                }

                let annoName = "\(day)/\(id.uuidString)-annotations.json"
                if annotations.isEmpty {
                    try? self.manager.removeItem(at: root.appendingPathComponent(annoName))
                } else if let annoData = try? JSONEncoder().encode(annotations) {
                    try? RecentCaptureStore.write(annoData, to: root.appendingPathComponent(annoName))
                }

                if !self.store.entries.contains(where: { $0.id == id }) {
                    self.prepend(entry)
                } else {
                    self.store.persist()
                    self.publish()
                }
            } catch {
                return
            }
        }
    }

    func stashRecording(from sourceURL: URL, completion: @escaping (URL?) -> Void) {
        let id = UUID()
        let createdAt = Date()
        let day = Self.dayFormatter.string(from: createdAt)
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let relativePath = "\(day)/\(id.uuidString).\(ext)"
        let thumbnailName = "\(id.uuidString)-thumbnail.png"
        let generation = currentClearGeneration()
        let entry = RecentCaptureEntry(
            id: id, kind: .recording, createdAt: createdAt,
            screenshotName: nil, recordingPath: relativePath, thumbnailName: nil, scale: nil,
            anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil)

        queue.async { [weak self] in
            guard let self, self.currentClearGeneration() == generation,
                  let root = self.capturesRoot,
                  self.store.importRecording(from: sourceURL, entry: entry) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let destination = root.appendingPathComponent(relativePath)
            self.pruneMissingEntries()
            self.store.persist()
            self.publish()
            DispatchQueue.main.async { [weak self] in
                completion(destination)
                // Thumbnail work cannot leave an unindexed movie exposed to cleanup.
                Task { @MainActor [weak self] in
                    let thumbnail = await Self.recordingThumbnail(at: destination)
                    self?.storeRecording(at: destination, recordingPath: relativePath,
                                         id: id, createdAt: createdAt,
                                         thumbnailName: thumbnailName, thumbnail: thumbnail,
                                         generation: generation)
                }
            }
        }
    }

    func recordRecording(at url: URL) {
        guard RecentCaptureStore.isRegularFile(url) else { return }
        let id = UUID()
        let thumbnailName = "\(id.uuidString)-thumbnail.png"
        let createdAt = Date()
        let generation = currentClearGeneration()

        Task { @MainActor [weak self] in
            let thumbnail = await Self.recordingThumbnail(at: url)
            self?.storeRecording(at: url,
                                 recordingPath: url.standardizedFileURL.path,
                                 id: id,
                                 createdAt: createdAt,
                                 thumbnailName: thumbnailName,
                                 thumbnail: thumbnail,
                                 generation: generation)
        }
    }

    private func storeRecording(at url: URL,
                                recordingPath: String,
                                id: UUID,
                                createdAt: Date,
                                thumbnailName: String,
                                thumbnail: CGImage?,
                                generation: Int) {
        queue.async { [weak self] in
            guard let self, self.currentClearGeneration() == generation,
                  RecentCaptureStore.isRegularFile(url) else { return }
            guard self.store.loadIfNeeded() else { return }
            var storedThumbnail: String?
            if let thumbnail,
               let thumbnailRoot = self.thumbnailRoot,
               let data = ScreenshotRenderer.pngData(from: thumbnail, scale: 1),
               (try? RecentCaptureStore.write(data, to: thumbnailRoot.appendingPathComponent(thumbnailName))) != nil {
                storedThumbnail = thumbnailName
            }
            guard self.currentClearGeneration() == generation else {
                if let storedThumbnail, let thumbnailRoot = self.thumbnailRoot {
                    try? self.manager.removeItem(
                        at: thumbnailRoot.appendingPathComponent(storedThumbnail))
                }
                return
            }
            let entry = RecentCaptureEntry(
                id: id,
                kind: .recording,
                createdAt: createdAt,
                screenshotName: nil,
                recordingPath: recordingPath,
                thumbnailName: storedThumbnail,
                scale: nil,
                anchorX: nil,
                anchorY: nil,
                anchorWidth: nil,
                anchorHeight: nil)
            self.prepend(entry)
        }
    }

    func remove(_ entry: RecentCaptureEntry) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.store.loadIfNeeded() else { return }
            guard self.store.entries.contains(where: { $0.id == entry.id }) else { return }
            self.store.entries.removeAll { $0.id == entry.id }
            self.store.persist()
            self.publish()
        }
    }

    func clear() {
        generationLock.lock()
        clearGeneration &+= 1
        generationLock.unlock()
        queue.async { [weak self] in
            guard let self else { return }
            guard self.store.loadIfNeeded() else { return }
            self.store.entries.removeAll()
            self.store.persist()
            self.thumbnailCache.removeAllObjects()
            self.publish()
        }
    }

    func thumbnail(for entry: RecentCaptureEntry) -> NSImage? {
        guard let name = entry.thumbnailName, Self.isSafeName(name) else { return nil }
        let key = name as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        if let thumbnailRoot,
           let image = NSImage(contentsOf: thumbnailRoot.appendingPathComponent(name)) {
            thumbnailCache.setObject(image, forKey: key)
            return image
        }
        if entry.kind == .screenshot,
           let capture = loadScreenshot(entry),
           let smallCG = Self.thumbnail(from: capture.image) {
            let image = NSImage(cgImage: smallCG, size: NSSize(width: smallCG.width, height: smallCG.height))
            thumbnailCache.setObject(image, forKey: key)
            if let thumbnailRoot,
               let data = ScreenshotRenderer.pngData(from: smallCG, scale: 1) {
                try? RecentCaptureStore.write(data, to: thumbnailRoot.appendingPathComponent(name))
            }
            return image
        }
        return nil
    }

    func open(_ entry: RecentCaptureEntry) {
        hideHistoryWindow()
        switch entry.kind {
        case .screenshot:
            restoreScreenshot(entry)
        case .recording:
            guard let url = entry.recordingURL, RecentCaptureStore.isRegularFile(url) else {
                remove(entry)
                NSSound.beep()
                return
            }
            appDelegate()?.closePopover()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func restoreScreenshot(_ entry: RecentCaptureEntry) {
        queue.async { [weak self] in
            guard let self, let capture = self.loadScreenshot(entry) else {
                DispatchQueue.main.async { [weak self] in
                    self?.remove(entry)
                    NSSound.beep()
                }
                return
            }
            DispatchQueue.main.async {
                appDelegate()?.closePopover()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    ScreenshotService.shared.restorePreview(capture)
                }
            }
        }
    }

    private func loadScreenshot(_ entry: RecentCaptureEntry)
        -> ScreenshotSelectionController.Capture? {
        guard entry.kind == .screenshot,
              let name = entry.screenshotName,
              Self.isSafeRelativePath(name),
              let capturesRoot,
              let scale = entry.scale,
              scale.isFinite, scale > 0
        else { return nil }

        let parts = name.split(separator: "/")
        let day = parts.count > 1 ? String(parts[0]) : nil
        let baseName = day != nil ? "\(day!)/\(entry.id.uuidString)-base.png" : "\(entry.id.uuidString)-base.png"
        let baseCandidate = capturesRoot.appendingPathComponent(baseName)
        let imageURL = manager.fileExists(atPath: baseCandidate.path) ? baseCandidate : capturesRoot.appendingPathComponent(name)

        guard let source = CGImageSourceCreateWithURL(
                imageURL as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(
                source, 0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }

        var loadedAnnotations: [ScreenshotSupport.Annotation] = []
        let annoName = day != nil ? "\(day!)/\(entry.id.uuidString)-annotations.json" : "\(entry.id.uuidString)-annotations.json"
        let annoURL = capturesRoot.appendingPathComponent(annoName)
        if let data = try? Data(contentsOf: annoURL),
           let decoded = try? JSONDecoder().decode([ScreenshotSupport.Annotation].self, from: data) {
            loadedAnnotations = decoded
        }

        let anchor = CGRect(
            x: entry.anchorX ?? 0,
            y: entry.anchorY ?? 0,
            width: entry.anchorWidth ?? 0,
            height: entry.anchorHeight ?? 0)
        return ScreenshotSelectionController.Capture(
            id: entry.id,
            image: image,
            scale: CGFloat(scale),
            anchorRect: anchor,
            annotations: loadedAnnotations
        )
    }

    private func pruneMissingEntries() {
        let days = CleanerPolicy.sanitizedScreenshotAgeDays(
            UserDefaults.standard.integer(forKey: DefaultsKey.cleanerScreenshotAgeDays))
        let cutoff = days > 0 ? Date().addingTimeInterval(-Double(days) * 86_400) : nil
        store.entries = RecentCaptureRetention.entries(
            store.entries.filter { entryExists($0) }, screenshotCutoff: cutoff,
            recordingLimit: UserDefaults.standard.integer(forKey: DefaultsKey.recentRecordingLimit))
    }

    private func prepend(_ entry: RecentCaptureEntry) {
        if let path = entry.recordingPath,
           let previous = store.entries.first(where: { $0.recordingPath == path }) {
            store.entries.removeAll { $0.id == previous.id }
        }
        store.entries.append(entry)
        store.entries.sort { $0.createdAt > $1.createdAt }
        pruneMissingEntries()
        store.persist()
        publish()
    }

    private func entryExists(_ entry: RecentCaptureEntry) -> Bool {
        switch entry.kind {
        case .screenshot:
            guard let name = entry.screenshotName, Self.isSafeRelativePath(name), let capturesRoot else { return false }
            return RecentCaptureStore.isRegularFile(capturesRoot.appendingPathComponent(name))
        case .recording:
            guard let url = entry.recordingURL else { return false }
            return RecentCaptureStore.isRegularFile(url)
        }
    }

    private static func isSafeRelativePath(_ name: String) -> Bool {
        RecentCaptureStore.isSafeRelativePath(name)
    }

    private func publish() {
        let value = store.entries
        DispatchQueue.main.async { [weak self] in
            self?.entries = value
            DispatchQueue.main.async { [weak self] in self?.refreshPanelLayout() }
        }
    }

    private func currentClearGeneration() -> Int {
        generationLock.lock()
        defer { generationLock.unlock() }
        return clearGeneration
    }

    private static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name == URL(fileURLWithPath: name).lastPathComponent
    }

    private static func thumbnail(from image: CGImage) -> CGImage? {
        let maximum = CGFloat(360)
        let longest = CGFloat(max(image.width, image.height))
        let factor = min(1, maximum / max(1, longest))
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func recordingThumbnail(at url: URL) async -> CGImage? {
        if url.pathExtension.lowercased() == "gif" {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 360,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 360)
        return try? await generator.image(at: .zero).image
    }
}
