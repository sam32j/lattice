import Foundation

extension DefaultsKey {
    // Missing means unpaused, preserving existing installations' explicit setup.
    static let brightnessKeyStepPaused = "brightnessKeyStepPaused"
}

/// Saved step size is configuration, not permission to resume interception.
enum BrightnessKeyStepActivation {
    static func effective(in defaults: UserDefaults) -> BrightnessSupport.KeyStep {
        effective(raw: defaults.string(forKey: DefaultsKey.brightnessKeyStep),
                  paused: defaults.bool(forKey: DefaultsKey.brightnessKeyStepPaused))
    }

    static func effective(raw: String?, paused: Bool) -> BrightnessSupport.KeyStep {
        paused ? .standard : .sanitized(raw)
    }

    @discardableResult
    static func pause(in defaults: UserDefaults) -> Bool {
        let wasActive = effective(in: defaults) != .standard
        defaults.set(true, forKey: DefaultsKey.brightnessKeyStepPaused)
        return wasActive
    }
}
