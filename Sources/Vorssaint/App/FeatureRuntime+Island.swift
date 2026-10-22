import Foundation

extension FeatureRuntime {
    /// Each dedicated Island control owns both its saved preference and installation.
    func setIslandFeature(_ feature: AppFeature, enabled: Bool) {
        precondition(feature == .notch || AppFeature.dynamicIslandExtensions.contains(feature))
        for key in feature.enabledKeys { UserDefaults.standard.set(enabled, forKey: key) }
        setAvailable([feature], enabled)
        // Preference-only transitions also need to reach an already installed service.
        sync([feature])
    }
}
