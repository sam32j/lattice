import Foundation

/// Production synchronization and recovery with an inert Bluetooth controller.
enum BluetoothSleepPreferencesTests {
    class State {
        let defaults: UserDefaults
        let isSupported = true
        var isPoweredOn = false
        var monitoring = false
        var powerChanges = [Bool]()
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func start() { monitoring = true }
        func stop() { monitoring = false }
        func setPowered(_ on: Bool) { powerChanges.append(on); isPoweredOn = on }
    }

    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.bluetooth-preferences.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for sleep in [false, true] {
            for restore in [false, true] {
                defaults.set(sleep, forKey: DefaultsKey.bluetoothSleepEnabled)
                defaults.set(restore, forKey: DefaultsKey.bluetoothSleepRestoreOnWake)
                defaults.set(false, forKey: DefaultsKey.bluetoothSleepRestorePending)
                let service = Service(defaults)
                service.syncWithPreferences()
                suite.expect(service.monitoring == sleep && service.powerChanges.isEmpty,
                             "only sleep handling starts monitoring, and a saved restore option never changes power")
                defaults.set(false, forKey: DefaultsKey.bluetoothSleepEnabled)
                service.syncWithPreferences()
                suite.expect(!service.monitoring
                             && defaults.bool(forKey: DefaultsKey.bluetoothSleepRestoreOnWake) == restore,
                             "disabling sleep handling stops monitoring without erasing the saved restore choice")
                for powered in [false, true] {
                    defaults.set(true, forKey: DefaultsKey.bluetoothSleepRestorePending)
                    let recovery = Service(defaults)
                    recovery.isPoweredOn = powered
                    recovery.syncWithPreferences()
                    suite.expect(recovery.isPoweredOn && !recovery.monitoring
                                 && recovery.powerChanges == (powered ? [] : [true])
                                 && !defaults.bool(forKey: DefaultsKey.bluetoothSleepRestorePending),
                                 "an owed restore is settled with sleep off, regardless of the saved restore option")
                    recovery.syncWithPreferences()
                    suite.expect(recovery.powerChanges == (powered ? [] : [true]),
                                 "a settled restore is not repeated on subsequent synchronization")
                }
            }
        }
    }
}
