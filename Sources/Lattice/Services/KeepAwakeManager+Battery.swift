import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

extension KeepAwakeManager {
    // MARK: - Battery protection

    func startBatteryWatch() {
        stopBatteryWatch()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        batteryTimer = t
        checkBattery()
    }

    func stopBatteryWatch() {
        batteryTimer?.invalidate()
        batteryTimer = nil
    }

    func checkBattery() {
        guard isActive, batteryProtectionPercent() != nil else { return }
        deactivate(reason: .battery)
    }

    /// The battery level while battery protection would end any session at
    /// once (on battery, at or below the limit); nil when a session can run.
    func batteryProtectionPercent() -> Int? {
        let limit = Defaults.sanitizedBatteryLimit(UserDefaults.standard.integer(forKey: DefaultsKey.batteryLimit))
        guard limit > 0,
              let battery = SystemInfo.batterySnapshot(),
              battery.isOnBattery,
              battery.percent <= limit else { return nil }
        return battery.percent
    }
}
