import Combine
import Foundation
import CoreBluetooth

/// An application-lifetime subscriber, independent of whether Settings is open.
enum PermissionRevocationRuntime {
    static func observe() -> AnyCancellable {
        var tracker = PermissionRevocationTracker(defaults: .standard)
        return Publishers.CombineLatest(Permissions.shared.$verifiedPermissions, BluetoothPermissionAccess.shared.$authorization)
            .map { verified, authorization in
                var all = verified
                all[.bluetooth] = authorization == .allowedAlways
                return all
            }
            .receive(on: DispatchQueue.main)
            .sink { verified in
                let current = Dictionary(uniqueKeysWithValues: verified.keys.map {
                    ($0, PermissionPreflight.revocationReading($0))
                })
                let lost = tracker.update(current)
                guard !lost.isEmpty else { return }
                let changes = PermissionRevocationPolicy.apply(lost, in: .standard)
                let runtime = FeatureRuntime.shared
                if changes.endsCleaningLock { CleaningModeManager.shared.deactivateForSystemTeardown() }
                if !changes.affected.isEmpty {
                    runtime.sync(Array(changes.affected))
                    runtime.finishAvailabilityChange()
                }
            }
    }
}
