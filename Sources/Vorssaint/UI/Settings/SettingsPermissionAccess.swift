// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import EventKit

/// Live, synchronous verification separated from the asynchronously published UI cache.
enum SettingsPermissionAccess {
    static func isGranted(_ permission: SettingsPermission) -> Bool {
        switch permission {
        case .accessibility: return AXIsProcessTrusted()
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        case .camera: return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphone: return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .calendar: return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        }
    }

    static func request(_ permission: SettingsPermission,
                        completion: @escaping (SettingsPermissionResult) -> Void) {
        let permissions = Permissions.shared
        switch permission {
        case .accessibility:
            permissions.requestAccessibility()
            if isGranted(permission) { completion(.granted) }
            else {
                completion(.needsSettings)
                permissions.openAccessibilitySettings()
            }
        case .screenRecording:
            permissions.requestScreenRecording()
            if isGranted(permission) { completion(.granted) }
            else {
                completion(.needsSettings)
                permissions.openScreenRecordingSettings()
            }
        case .camera, .microphone:
            let media: AVMediaType = permission == .camera ? .video : .audio
            let status = AVCaptureDevice.authorizationStatus(for: media)
            guard status == .notDetermined else {
                completion(status == .authorized ? .granted : .needsSettings)
                if status != .authorized {
                    if permission == .camera { permissions.openCameraSettings() }
                    else { permissions.openMicrophoneSettings() }
                }
                return
            }
            AVCaptureDevice.requestAccess(for: media) { granted in
                DispatchQueue.main.async {
                    permissions.refresh()
                    completion(granted ? .granted : .denied)
                }
            }
        case .calendar:
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .denied || status == .restricted {
                completion(.needsSettings)
                permissions.openCalendarSettings()
                return
            }
            let store = EKEventStore()
            store.requestFullAccessToEvents { [store] granted, error in
                _ = store
                DispatchQueue.main.async {
                    permissions.refresh()
                    completion(granted && error == nil ? .granted : .denied)
                }
            }
        }
    }
}
