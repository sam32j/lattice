import ApplicationServices
import AVFoundation
import CoreGraphics
import EventKit
import CoreBluetooth

/// Side-effect-free live checks shared by activation and revocation owners.
enum PermissionPreflight {
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
