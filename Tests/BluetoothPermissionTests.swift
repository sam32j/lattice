import CoreBluetooth

enum BluetoothPermissionTests {
    static func run(_ suite: TestSuite) {
        suite.expect(BluetoothAuthorizationPolicy.status(.allowedAlways) == .granted,
                     "Bluetooth allowed status is shown as granted")
        for state in [CBManagerAuthorization.denied, .restricted, .notDetermined] {
            suite.expect(BluetoothAuthorizationPolicy.status(state) == .missing,
                         "unavailable Bluetooth authorization is never shown as granted")
        }
        suite.expect(BluetoothAuthorizationPolicy.canRequest(.notDetermined)
                     && !BluetoothAuthorizationPolicy.canRequest(.denied)
                     && !BluetoothAuthorizationPolicy.canRequest(.restricted)
                     && !BluetoothAuthorizationPolicy.canRequest(.allowedAlways),
                     "only an undecided Bluetooth permission offers a request; denied access uses System Settings")
        suite.expect(AppPermission.allCases.contains(.bluetooth), "Bluetooth is available in the Permissions page")
        let activityKeys = [DefaultsKey.notchEnabled, DefaultsKey.notchAccessoriesEnabled]
        let withoutPower = AppFeature.activeFeatures(using: .bluetooth,
            isAvailable: { $0 != .monitorPower }, boolFor: { activityKeys.contains($0) }, stringFor: { _ in nil })
        suite.expect(withoutPower.isEmpty,
                     "an island accessory activity cannot claim Bluetooth use while its power module is uninstalled")
        let withPower = AppFeature.activeFeatures(using: .bluetooth,
            isAvailable: { _ in true }, boolFor: { activityKeys.contains($0) }, stringFor: { _ in nil })
        suite.expect(withPower == [.notchAccessories],
                     "enabled island accessory observation is attributed without unrelated power-alert consumers")
    }
}
