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
        defaults.set("", forKey: DefaultsKey.notchHiddenModules)
        for previews in [false, true] {
            defaults.set(previews, forKey: DefaultsKey.notchCapture)
            suite.expect(NotchSupport.routesCapturePreviews(in: defaults) == previews,
                         "capture previews retain their own destination")
        }
        defaults.set(false, forKey: AppFeature.screenshot.availabilityKey)
        defaults.set(true, forKey: AppFeature.screenRecorder.availabilityKey)
        suite.expect(NotchSupport.routesCapturePreviews(in: defaults),
                     "recording previews and live controls remain usable in a recorder-only setup")
    }
}
