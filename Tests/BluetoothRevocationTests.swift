import Foundation

enum BluetoothRevocationTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.bluetooth-revocation.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchAccessoriesEnabled)
        defaults.set(true, forKey: DefaultsKey.monitorPwrPeripherals)
        let changes = PermissionRevocationPolicy.apply([.bluetooth: false], in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled)
                     && defaults.bool(forKey: DefaultsKey.notchEnabled)
                     && defaults.bool(forKey: DefaultsKey.monitorPwrPeripherals)
                     && changes.affected.contains(.notchAccessories),
                     "Bluetooth reset disables island accessories without disabling the island or non-Bluetooth battery readings")
        _ = PermissionRevocationPolicy.apply([.bluetooth: true, .accessibility: true], in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled),
                     "restoring Accessibility or Bluetooth alone never rearms island accessories")
        var authorized = false
        var callback: ((SettingsPermissionResult) -> Void)?
        let activation = PermissionActivationCoordinator(requirements: [.bluetooth], verify: { _ in authorized },
            requestAccess: { _, reply in callback = reply },
            applyEnabled: { defaults.set($0, forKey: DefaultsKey.notchAccessoriesEnabled) })
        activation.setEnabled(true)
        suite.expect(!defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled),
                     "explicit accessory enable remains off while its Bluetooth request is unanswered")
        authorized = true
        callback?(.granted)
        suite.expect(defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled),
                     "only a verified grant completes the current explicit accessory enable")
    }
}
