import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Lifecycle

    var frequency: AppUpdatesSupport.CheckFrequency {
        AppUpdatesSupport.CheckFrequency.sanitized(
            UserDefaults.standard.string(forKey: DefaultsKey.appUpdatesCheckFrequency))
    }

    func syncWithPreferences() {
        reloadRules()
        if !AppFeature.appUpdates.isAvailable { cancelChecks() }
        guard AppFeature.appUpdates.isAvailable, frequency != .off else {
            stop()
            return
        }
        installWakeObserver()
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
        if nextCheck != nil { nextCheck = nil }
    }

    func installWakeObserver() {
        guard wakeObserver == nil else { return }
        // A check that came due during sleep never fires its timer; waking up
        // recomputes and catches the miss.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.scheduleNext()
        }
    }

    func scheduleNext() {
        guard AppFeature.appUpdates.isAvailable else { return }
        guard let fireDate = AppUpdatesSupport.nextCheckDate(lastCheck: lastCheck,
                                                             frequency: frequency,
                                                             now: Date()) else { return }
        timer?.invalidate()
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            self?.check(automatic: true)
        }
        // One shot a day: a loose tolerance costs nothing and lets the system
        // group the wake-up with other work.
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        if nextCheck != fireDate { nextCheck = fireDate }
    }

    /// Cancel the check generation before releasing schedules or UI state.
    func cancelChecks() {
        scanGeneration += 1
        checkCancellation?.cancel()
        checkCancellation = nil
        isChecking = false
        sourceRefreshPending = false
        automaticCheckPending = false
        upgradeObserver = nil
        pendingUpdateHandoffs.removeAll()
    }
}
