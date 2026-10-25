import Foundation
import Combine
import CoreBluetooth

/// The production observer runs with isolated preferences and inert services.
enum PermissionRevocationRuntimeTests {
    enum Permissions {
        static let shared = Store()
        final class Store: ObservableObject {
            @Published var verifiedPermissions: [SettingsPermission: Bool] = [:]
        }
    }
    enum BluetoothPermissionAccess {
        static let shared = Store()
        final class Store: ObservableObject {
            @Published var authorization = CBManagerAuthorization.notDetermined
        }
    }
    enum PermissionPreflight {
        static var granted = false
        static var explicitDenial = false
        static func revocationReading(_ permission: SettingsPermission) -> PermissionRevocationTracker.Reading {
            granted ? .granted : explicitDenial ? .denied : .unverified
        }
    }
    enum CleaningModeManager {
        static let shared = Service()
        final class Service { func deactivateForSystemTeardown() {} }
    }
    enum FeatureRuntime {
        static let shared = Service()
        final class Service {
            func sync(_ features: [AppFeature]) {}
            func finishAvailabilityChange() {}
        }
    }
    static var defaults: UserDefaults!
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.revocation-observer.\(UUID())"
        defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); defaults = nil }
        defaults.set(true, forKey: DefaultsKey.keyboardDebounceEnabled)
        defaults.set(true, forKey: DefaultsKey.notchAccessoriesEnabled)
        PermissionPreflight.granted = false
        Permissions.shared.verifiedPermissions = [.accessibility: false]
        BluetoothPermissionAccess.shared.authorization = .notDetermined
        let observation = Observer.observe()
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        suite.expect(defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
                     && defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled),
                     "the initial never-granted snapshot does not revoke saved activation")
        PermissionPreflight.granted = true
        Permissions.shared.verifiedPermissions = [.accessibility: true]
        BluetoothPermissionAccess.shared.authorization = .allowedAlways
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        PermissionPreflight.granted = false
        Permissions.shared.verifiedPermissions = [.accessibility: false]
        BluetoothPermissionAccess.shared.authorization = .notDetermined
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        suite.expect(!defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
                     && !defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled),
                     "a known grant lost to reset revokes activation immediately")
        defaults.set(true, forKey: DefaultsKey.notchAccessoriesEnabled)
        PermissionPreflight.explicitDenial = true
        BluetoothPermissionAccess.shared.authorization = .denied
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        suite.expect(!defaults.bool(forKey: DefaultsKey.notchAccessoriesEnabled),
                     "an explicit denial is handled even when the reported boolean stays false")
        PermissionPreflight.explicitDenial = false
        withExtendedLifetime(observation) {}
    }
}
