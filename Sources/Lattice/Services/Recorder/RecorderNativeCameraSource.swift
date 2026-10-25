// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation

enum RecorderCaptureInputs {
    static var cameras: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified).devices
    }
    static var microphones: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external],
            mediaType: .audio, position: .unspecified).devices
    }
}

/// Every mutation of the AVCaptureSession is confined to this serial queue.
final class RecorderNativeCameraSource: NSObject, RecorderCameraSource,
                                        AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "io.github.sam32j.lattice.recorder.camera", qos: .userInitiated)
    private var session: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var active: RecorderCameraRequest?
    private var frame: ((CVPixelBuffer) -> Void)?
    private var failure: ((String) -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start(deviceID: String?, request: RecorderCameraRequest,
               onFrame: @escaping (CVPixelBuffer) -> Void,
               onFailure: @escaping (String) -> Void) async throws {
        guard !request.isCancelled else { throw CancellationError() }
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        guard authorized else { throw error("Camera access is not allowed. Enable it in System Settings.") }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                guard !request.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                stopCurrent()
                do {
                    let device = deviceID.flatMap { id in RecorderCaptureInputs.cameras.first { $0.uniqueID == id } }
                        ?? (deviceID == nil ? AVCaptureDevice.default(for: .video) : nil)
                    guard let device, device.isConnected else { throw error("The selected camera is unavailable.") }
                    let input = try AVCaptureDeviceInput(device: device)
                    let output = AVCaptureVideoDataOutput()
                    output.alwaysDiscardsLateVideoFrames = true
                    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    let session = AVCaptureSession()
                    session.beginConfiguration()
                    session.sessionPreset = .high
                    guard session.canAddInput(input), session.canAddOutput(output) else {
                        session.commitConfiguration()
                        throw error("The camera cannot provide video for this recording.")
                    }
                    session.addInput(input)
                    session.addOutput(output)
                    output.setSampleBufferDelegate(self, queue: queue)
                    session.commitConfiguration()
                    self.session = session
                    videoOutput = output
                    active = request
                    frame = onFrame
                    failure = onFailure
                    observe(session, device: device)
                    session.startRunning()
                    guard session.isRunning, !request.isCancelled else {
                        stopCurrent()
                        throw error("The camera could not start.")
                    }
                    continuation.resume()
                } catch {
                    stopCurrent()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop(request: RecorderCameraRequest) async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if active === request { stopCurrent() }
                continuation.resume()
            }
        }
    }

    private func observe(_ session: AVCaptureSession, device: AVCaptureDevice) {
        let center = NotificationCenter.default
        for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
            observers.append(center.addObserver(forName: name, object: session, queue: nil) { [weak self, weak session] _ in
                if let session { self?.reportUnavailable(session) }
            })
        }
        observers.append(center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification,
            object: device, queue: nil) { [weak self, weak session] _ in
                if let session { self?.reportUnavailable(session) }
            })
    }
    private func reportUnavailable(_ failedSession: AVCaptureSession) {
        queue.async { [self] in
            guard session === failedSession else { return }
            let callback = failure
            stopCurrent()
            callback?("The camera disconnected or became unavailable. Recording has stopped.")
        }
    }
    private func stopCurrent() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        if session?.isRunning == true { session?.stopRunning() }
        session = nil
        videoOutput = nil
        active = nil
        frame = nil
        failure = nil
    }
    private func error(_ message: String) -> NSError {
        NSError(domain: "Lattice.RecorderCamera", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard output === videoOutput, active?.isCancelled == false,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frame?(pixels)
    }
}
