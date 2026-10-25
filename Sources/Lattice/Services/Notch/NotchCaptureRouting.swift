import Foundation

/// Rich capture surfaces have destinations, not transient indicator events.
extension NotchSupport {
    static func routesCapturePreviews(in defaults: UserDefaults = .standard) -> Bool {
        isEnabled(in: defaults) && defaults.bool(forKey: DefaultsKey.notchCapture)
            && (AppFeature.screenshot.isAvailable(in: defaults)
                || AppFeature.screenRecorder.isAvailable(in: defaults))
            && modules(in: defaults).contains(.captures)
    }

}
