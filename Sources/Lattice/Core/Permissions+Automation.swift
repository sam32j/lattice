import AppKit
import Carbon
import Foundation

extension Permissions {
    enum AutomationTarget: String, CaseIterable {
        case finder = "com.apple.finder"
        case terminal = "com.apple.Terminal"
        case systemEvents = "com.apple.systemevents"
    }

    enum AutomationStatus {
        case granted, denied, undetermined, notDeterminable
    }

    /// Passive by default. Only an explicit Request action sets requestIfNeeded.
    /// A target that is not running reads as notDeterminable; no app is launched.
    /// Call off the main thread because Apple Event permission checks can block.
    static func automationStatus(for target: AutomationTarget, requestIfNeeded: Bool = false) -> AutomationStatus {
        var descriptor = AEAddressDesc()
        let bundleID = target.rawValue
        let created = bundleID.withCString { pointer in
            AECreateDesc(typeApplicationBundleID, pointer, bundleID.utf8.count, &descriptor)
        }
        guard created == noErr else { return .notDeterminable }
        defer { AEDisposeDesc(&descriptor) }
        switch AEDeterminePermissionToAutomateTarget(&descriptor, typeWildCard, typeWildCard, requestIfNeeded) {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .undetermined
        default: return .notDeterminable
        }
    }
    static func requestAutomation(_ target: AutomationTarget, completion: @escaping (AutomationStatus) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status = automationStatus(for: target, requestIfNeeded: true)
            DispatchQueue.main.async { completion(status) }
        }
    }
}
