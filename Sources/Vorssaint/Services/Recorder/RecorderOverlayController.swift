// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Owns only the live recording overlays, never the standalone camera mirror.
final class RecorderOverlayController: ObservableObject {
    static let shared = RecorderOverlayController()
    let frames: RecorderOverlayFrameStore
    @Published var cameraEnabled = false { didSet { if oldValue != cameraEnabled { configureCamera() } } }
    @Published var keysEnabled = false { didSet { updateKeyCapture() } }
    @Published var selectedCameraID: String? { didSet { if oldValue != selectedCameraID, cameraEnabled { configureCamera() } } }
    @Published var selectedMicrophoneID: String?
    @Published var layout = RecorderCameraLayout() { didSet { frames.setLayout(layout); refreshLayout() } }
    @Published private(set) var errorMessage: String?
    @Published private(set) var cameraReady = false
    private(set) var pixelSize = CGSize.zero
    private var anchorRect = CGRect.zero
    private let camera: RecorderCameraCapture
    private let keys: RecorderKeystrokeOverlay
    private var cameraTask: Task<Bool, Never>?
    private var cameraGeneration = 0
    private var cameraPanel: RecorderOverlayPanel?
    private var keyPanel: RecorderOverlayPanel?
    private var refreshTimer: Timer?
    private var pauseClock: RecorderPauseClock?
    var isRecording: Bool { pauseClock != nil }
    var onFailure: ((String) -> Void)?
    var excludedWindowNumbers: [Int] {
        [cameraPanel?.windowNumber, keyPanel?.windowNumber].compactMap { number in
            guard let number, number > 0 else { return nil }; return number
        }
    }

    init(source: any RecorderCameraSource = RecorderNativeCameraSource()) {
        let frames = RecorderOverlayFrameStore()
        self.frames = frames
        camera = RecorderCameraCapture(source: source, frames: frames)
        keys = RecorderKeystrokeOverlay(frames: frames)
        keys.onImage = { [weak self] image in self?.showKeyImage(image) }
    }

    func updateRegion(anchorRect: CGRect, pixelSize: CGSize) {
        guard anchorRect.width > 0, anchorRect.height > 0, pixelSize.width > 0, pixelSize.height > 0 else { return }
        self.anchorRect = anchorRect
        self.pixelSize = pixelSize
        frames.setLayout(layout)
        refreshLayout()
    }

    func prepareRecording(anchorRect: CGRect, pixelSize: CGSize) {
        updateRegion(anchorRect: anchorRect, pixelSize: pixelSize)
        if keysEnabled { ensureKeyPanel() }
    }

    @MainActor func ensureCameraReady() async -> Bool {
        guard cameraEnabled else { return true }
        let generation = cameraGeneration
        guard let cameraTask, await cameraTask.value else { return false }
        for _ in 0..<150 {
            guard cameraEnabled, cameraGeneration == generation else { return false }
            if camera.hasCurrentFrame { cameraReady = true; return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        if cameraEnabled, cameraGeneration == generation {
            reportFailure("The camera did not provide any video. Try another camera.")
        }
        return false
    }

    func startRecording(pauseClock: RecorderPauseClock) {
        self.pauseClock = pauseClock
        updateKeyCapture()
    }
    func pauseChanged() { updateKeyCapture() }
    func dismissError() { errorMessage = nil }
    func toggleCamera() {
        if cameraEnabled { layout.isFullArea = false }
        cameraEnabled.toggle()
    }

    func moveCamera(origin: CGPoint) {
        guard anchorRect.width > 0 else { return }
        let xScale = pixelSize.width / anchorRect.width
        let yScale = pixelSize.height / anchorRect.height
        layout.place(origin: CGPoint(x: (origin.x - anchorRect.minX) * xScale,
                                     y: (origin.y - anchorRect.minY) * yScale), in: pixelSize)
    }

    func stop() {
        cameraEnabled = false
        keysEnabled = false
        cameraGeneration &+= 1
        cameraTask?.cancel()
        cameraTask = nil
        _ = camera.stop()
        keys.stop()
        pauseClock = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        cameraPanel?.orderOut(nil)
        keyPanel?.orderOut(nil)
        cameraPanel = nil
        keyPanel = nil
        anchorRect = .zero
        pixelSize = .zero
        frames.clear()
        layout.isFullArea = false
        cameraReady = false
        onFailure = nil
    }

    private func configureCamera() {
        cameraGeneration &+= 1
        let generation = cameraGeneration
        cameraReady = false
        if !cameraEnabled {
            _ = camera.stop()
            cameraPanel?.orderOut(nil)
            refreshTimer?.invalidate()
            refreshTimer = nil
            return
        }
        errorMessage = nil
        cameraTask = camera.start(deviceID: selectedCameraID) { [weak self] message in
            DispatchQueue.main.async {
                guard let self, self.cameraGeneration == generation, self.cameraEnabled else { return }
                self.reportFailure(message)
            }
        }
        let pending = cameraTask
        Task { @MainActor [weak self] in
            let started = await pending?.value == true
            guard let self, self.cameraGeneration == generation, self.cameraEnabled else { return }
            if !started { self.reportFailure(self.camera.lastError ?? "The selected camera could not start.") }
        }
        refreshLayout()
    }

    private func reportFailure(_ message: String) {
        errorMessage = message
        cameraEnabled = false
        onFailure?(message)
    }

    private func refreshLayout() {
        guard cameraEnabled, anchorRect.width > 0, pixelSize.width > 0 else { return }
        if cameraPanel == nil {
            let panel = RecorderOverlayPanel()
            panel.contentView = RecorderCameraOverlayView(controller: self)
            cameraPanel = panel
        }
        let frame = layout.frame(in: pixelSize)
        let points = CGRect(x: anchorRect.minX + frame.minX * anchorRect.width / pixelSize.width,
                            y: anchorRect.minY + frame.minY * anchorRect.height / pixelSize.height,
                            width: frame.width * anchorRect.width / pixelSize.width,
                            height: frame.height * anchorRect.height / pixelSize.height)
        cameraPanel?.setFrame(points, display: true)
        cameraPanel?.orderFrontRegardless()
        if refreshTimer == nil {
            let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in
                self?.cameraPanel?.contentView?.needsDisplay = true
            }
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }
    }

    private func updateKeyCapture() {
        keys.stop()
        guard keysEnabled, let pauseClock, !pauseClock.isPaused else { return }
        ensureKeyPanel()
        keys.start(pauseClock: pauseClock)
    }
    private func ensureKeyPanel() {
        guard keyPanel == nil else { return }
        let panel = RecorderOverlayPanel()
        panel.ignoresMouseEvents = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.contentsGravity = .resizeAspect
        keyPanel = panel
    }
    private func showKeyImage(_ image: CGImage?) {
        guard let image, pixelSize.width > 0 else { keyPanel?.orderOut(nil); return }
        ensureKeyPanel()
        let scale = min(1, pixelSize.width * 0.9 / CGFloat(image.width), pixelSize.height * 0.2 / CGFloat(image.height))
        let width = CGFloat(image.width) * scale * anchorRect.width / pixelSize.width
        let height = CGFloat(image.height) * scale * anchorRect.height / pixelSize.height
        let margin = min(28, pixelSize.height * 0.05) * anchorRect.height / pixelSize.height
        keyPanel?.setFrame(CGRect(x: anchorRect.midX - width / 2, y: anchorRect.minY + margin,
                                  width: width, height: height), display: true)
        keyPanel?.contentView?.layer?.contents = image
        keyPanel?.orderFrontRegardless()
    }
}
