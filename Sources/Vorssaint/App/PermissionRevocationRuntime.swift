import Combine
import Foundation
import CoreBluetooth

/// An application-lifetime subscriber, independent of whether Settings is open.
enum PermissionRevocationRuntime {
    static func observe() -> AnyCancellable {
        Publishers.CombineLatest(Permissions.shared.$verifiedPermissions, BluetoothPermissionAccess.shared.$authorization)
            .map { verified, authorization in
                var all = verified
                all[.bluetooth] = authorization == .allowedAlways
                return all
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { verified in
                let current = PermissionRevocationPolicy.revalidated(verified, verify: PermissionPreflight.isGranted)
                let changes = PermissionRevocationPolicy.apply(current, in: .standard)
                let runtime = FeatureRuntime.shared
                if changes.endsCleaningLock { CleaningModeManager.shared.deactivateForSystemTeardown() }
                if !changes.uninstall.isEmpty { runtime.setAvailable(Array(changes.uninstall), false) }
                if !changes.affected.isEmpty {
                    runtime.sync(Array(changes.affected))
                    runtime.finishAvailabilityChange()
                }
            }
    }
}
