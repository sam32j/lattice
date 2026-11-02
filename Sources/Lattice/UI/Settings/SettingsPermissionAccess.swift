// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import EventKit

/// Live, synchronous verification separated from the asynchronously published UI cache.
enum SettingsPermissionAccess {
    private static var attemptedAccessibility = false

    static func requestWithRecovery(_ permission: SettingsPermission,
                                    offerRecovery: @escaping (SettingsPermission) -> Void = showRecovery) {
        if permission == .accessibility {
            // AX prompting is asynchronous: its immediate false result is
            // still pending consent. Only a later explicit retry offers Settings.
            if attemptedAccessibility, !isGranted(permission) {
                offerRecovery(permission)
                return
            }
            attemptedAccessibility = true
        }
        request(permission) { result in
            if permission != .accessibility, result == .needsSettings || result == .denied {
                offerRecovery(permission)
            }
        }
    }

    private static func showRecovery(_ permission: SettingsPermission) {
        let strings = L10n.shared.s
        let alert = NSAlert()
        alert.messageText = strings.permissionRequired
        alert.informativeText = (permission == .accessibility
            ? strings.permissionAccessibility : strings.permissionScreenRecording) + "\n\n" + strings.permissionRestartNote
        alert.addButton(withTitle: strings.permissionOpenSettings)
        alert.addButton(withTitle: strings.mediaCancel)
        guard PermissionDialogPresentation.run(alert, over: NSApp.mainWindow) == .alertFirstButtonReturn else { return }
        if permission == .accessibility { Permissions.shared.openAccessibilitySettings() }
        else if permission == .screenRecording { Permissions.shared.openScreenRecordingSettings() }
    }

    static func isGranted(_ permission: SettingsPermission) -> Bool {
        PermissionPreflight.isGranted(permission)
    }

    static func request(_ permission: SettingsPermission,
                        completion: @escaping (SettingsPermissionResult) -> Void) {
        let permissions = Permissions.shared
        switch permission {
        case .accessibility:
            permissions.requestAccessibility(offerSettingsRecovery: false)
            if isGranted(permission) { completion(.granted) }
            else {
                completion(.needsSettings)
            }
        case .screenRecording:
            permissions.requestScreenRecording(offerSettingsRecovery: false)
            if isGranted(permission) { completion(.granted) }
            else {
                completion(.needsSettings)
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
        case .bluetooth:
            BluetoothPermissionAccess.shared.request { result in
                if case .needsSettings = result { BluetoothPermissionAccess.shared.openSettings() }
                completion(result)
            }
        }
    }
}
