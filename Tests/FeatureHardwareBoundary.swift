import Foundation

// The harness does not open SMC or query live displays. Capability-transition
// tests supply explicit support at the catalog's hardware boundary instead.
enum FeatureHardwareBoundary {
    static var unsupported = Set<AppFeature>()
}

extension AppFeature {
    var isHardwareSupported: Bool { !FeatureHardwareBoundary.unsupported.contains(self) }
}

// Never opens a keyboard-light driver in the standalone test process.
enum BrightnessService {
    static var keyboardLightIsSupported = true
}
