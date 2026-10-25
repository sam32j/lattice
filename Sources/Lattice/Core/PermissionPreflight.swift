import ApplicationServices
import AVFoundation
import CoreGraphics
import EventKit
import CoreBluetooth

/// Side-effect-free live checks shared by activation and revocation owners.
enum PermissionPreflight {
    static func revocationReading(_ permission: SettingsPermission) -> PermissionRevocationTracker.Reading {
        switch permission {
        case .accessibility, .screenRecording:
            return isGranted(permission) ? .granted : .unverified
        case .camera, .microphone:
            switch AVCaptureDevice.authorizationStatus(for: permission == .camera ? .video : .audio) {
            case .authorized: return .granted
            case .denied, .restricted: return .denied
            default: return .unverified
            }
        case .calendar:
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess: return .granted
            case .denied, .restricted, .writeOnly: return .denied
            default: return .unverified
            }
        case .bluetooth:
            switch CBManager.authorization {
            case .allowedAlways: return .granted
            case .denied, .restricted: return .denied
            default: return .unverified
            }
        }
    }

    static func isGranted(_ permission: SettingsPermission) -> Bool {
        switch permission {
        case .accessibility: return AXIsProcessTrusted()
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        case .camera: return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphone: return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .calendar: return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        case .bluetooth: return CBManager.authorization == .allowedAlways
        }
    }
}
