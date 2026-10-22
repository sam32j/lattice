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
        for controls in [false, true] {
            for previews in [false, true] {
                defaults.set(controls, forKey: DefaultsKey.notchCaptureControls)
                defaults.set(previews, forKey: DefaultsKey.notchCapture)
                suite.expect(NotchSupport.routesCaptureControls(in: defaults) == controls,
                             "live capture controls follow their own switch regardless of preview placement")
                suite.expect(NotchSupport.routesCapturePreviews(in: defaults) == previews,
                             "capture previews follow their destination regardless of the live controls switch")
            }
        }
        defaults.set(false, forKey: AppFeature.screenshot.availabilityKey)
        defaults.set(true, forKey: AppFeature.screenRecorder.availabilityKey)
        suite.expect(NotchSupport.routesCapturePreviews(in: defaults)
                     && NotchSupport.routesCaptureControls(in: defaults),
                     "recording previews and live controls remain usable in a recorder-only setup")
    }
}
