import Foundation

enum NotchCaptureRoutingTests {
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.capture-routing.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: AppFeature.screenshot.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.screenshotEnabled)
        for hidden in [true, false] {
            defaults.set(hidden ? "captures" : "", forKey: DefaultsKey.notchHiddenModules)
            suite.expect(NotchSupport.routesCapturePreviews(in: defaults) == !hidden,
                         "capture previews retain their own destination")
        }
        defaults.set("", forKey: DefaultsKey.notchHiddenModules)
        defaults.set(false, forKey: AppFeature.screenshot.availabilityKey)
        defaults.set(true, forKey: AppFeature.screenRecorder.availabilityKey)
        suite.expect(NotchSupport.routesCapturePreviews(in: defaults),
                     "recording previews and live controls remain usable in a recorder-only setup")
    }
}
