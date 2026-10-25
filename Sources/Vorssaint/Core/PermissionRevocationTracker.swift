import Foundation

/// Grant history is local machine state, deliberately outside portable backups.
/// A fresh, unrequested capability is not a revocation; an observed grant lost
/// to a reset is, including when the process was restarted in between.
struct PermissionRevocationTracker {
    enum Reading { case granted, denied, unverified }
    private static let historyKey = "permissionRevocationObservedGrants"
    private let defaults: UserDefaults
    private var granted: Set<String>

    init(defaults: UserDefaults) {
        self.defaults = defaults
        granted = Set(defaults.stringArray(forKey: Self.historyKey) ?? [])
    }

    mutating func update(_ current: [SettingsPermission: Reading]) -> [SettingsPermission: Bool] {
        let previous = granted
        var lost: [SettingsPermission: Bool] = [:]
        for (permission, reading) in current {
            let key = String(describing: permission)
            if reading == .granted { granted.insert(key) }
            else {
                if reading == .denied || granted.contains(key) { lost[permission] = false }
                granted.remove(key)
            }
        }
        if previous != granted { defaults.set(granted.sorted(), forKey: Self.historyKey) }
        return lost
    }
}
