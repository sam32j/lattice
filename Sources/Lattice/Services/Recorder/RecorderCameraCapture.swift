// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation

final class RecorderCameraRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}

/// The hardware boundary permits lifecycle tests without starting a real camera.
protocol RecorderCameraSource: AnyObject {
    func start(deviceID: String?, request: RecorderCameraRequest,
               onFrame: @escaping (CVPixelBuffer) -> Void,
               onFailure: @escaping (String) -> Void) async throws
    func stop(request: RecorderCameraRequest) async
}

final class RecorderCameraCapture: @unchecked Sendable {
    private let source: any RecorderCameraSource
    private let frames: RecorderOverlayFrameStore
    private let lock = NSLock()
    private var request: RecorderCameraRequest?
    private var failure: String?
    private var receivedFrame = false
    var lastError: String? { lock.lock(); defer { lock.unlock() }; return failure }
    var hasCurrentFrame: Bool { lock.lock(); defer { lock.unlock() }; return receivedFrame }

    init(source: any RecorderCameraSource = RecorderNativeCameraSource(), frames: RecorderOverlayFrameStore) {
        self.source = source
        self.frames = frames
    }

    /// Register cancellation synchronously, before an async permission request
    /// can yield. Rapid on/off/on cannot give an older task the newest camera.
    func start(deviceID: String?, onFailure: @escaping (String) -> Void = { _ in }) -> Task<Bool, Never> {
        let next = RecorderCameraRequest()
        lock.lock()
        request?.cancel()
        request = next
        failure = nil
        receivedFrame = false
        lock.unlock()
        return Task { [source, self] in
            do {
                try await source.start(deviceID: deviceID, request: next, onFrame: { [weak self] pixels in
                    self?.acceptFrame(pixels, request: next)
                }, onFailure: { [weak self] message in
                    guard self?.acceptFailure(message, request: next) == true else { return }
                    onFailure(message)
                })
                guard !next.isCancelled else { await source.stop(request: next); return false }
                return true
            } catch {
                self.recordFailure(error.localizedDescription, request: next)
                next.cancel()
                await source.stop(request: next)
                return false
            }
        }
    }

    private func acceptFrame(_ pixels: CVPixelBuffer, request: RecorderCameraRequest) {
        lock.lock(); defer { lock.unlock() }
        guard self.request === request, !request.isCancelled else { return }
        frames.setCamera(pixels)
        receivedFrame = true
    }

    private func acceptFailure(_ message: String, request: RecorderCameraRequest) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard self.request === request, !request.isCancelled else { return false }
        request.cancel()
        failure = message
        receivedFrame = false
        frames.setCamera(nil)
        return true
    }

    private func recordFailure(_ message: String, request: RecorderCameraRequest) {
        lock.lock(); defer { lock.unlock() }
        guard self.request === request else { return }
        failure = message
        frames.setCamera(nil)
    }

    func stop() -> Task<Void, Never> {
        lock.lock()
        let previous = request
        previous?.cancel()
        request = nil
        receivedFrame = false
        frames.setCamera(nil)
        lock.unlock()
        return Task { [source] in
            if let previous { await source.stop(request: previous) }
        }
    }
}
