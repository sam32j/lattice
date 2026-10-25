import Foundation

enum SwitcherPermissionRevocationTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.switcher-revocation.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for simple in [true, false] {
            defaults.set(simple, forKey: DefaultsKey.switcherSimpleMode)
            defaults.set(true, forKey: DefaultsKey.switcherEnabled)
            defaults.set(true, forKey: DefaultsKey.dockPreviewEnabled)
            let changes = PermissionRevocationPolicy.apply([.screenRecording: false], in: defaults)
            suite.expect(defaults.bool(forKey: DefaultsKey.switcherEnabled) == simple
                         && changes.affected.contains(.switcher) == !simple,
                         "Screen Recording loss preserves Simple Switcher but disables preview modes")
            suite.expect(!defaults.bool(forKey: DefaultsKey.dockPreviewEnabled)
                         && changes.affected.contains(.dockPreview),
                         "Dock Preview still requires Screen Recording in every Switcher mode")
            defaults.set(true, forKey: DefaultsKey.switcherEnabled)
            _ = PermissionRevocationPolicy.apply([.accessibility: false], in: defaults)
            suite.expect(!defaults.bool(forKey: DefaultsKey.switcherEnabled)
                         && defaults.bool(forKey: DefaultsKey.switcherSimpleMode) == simple,
                         "Accessibility loss still disables Switcher without changing its saved mode")
        }
    }
}
