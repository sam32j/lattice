import Foundation

extension NotchSize {
    /// Old development builds offered dimensions outside the supported presets.
    static func migratePreferences(in defaults: UserDefaults) {
        if defaults.string(forKey: DefaultsKey.notchSize) == "custom" {
            defaults.set(NotchSize.spacious.rawValue, forKey: DefaultsKey.notchSize)
        }
        defaults.removeObject(forKey: "notchCustomWidth")
        defaults.removeObject(forKey: "notchCustomHeight")
    }
}
