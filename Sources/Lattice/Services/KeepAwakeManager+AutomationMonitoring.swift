import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

extension KeepAwakeManager {
    // MARK: - Automatic sessions

    func syncAutomationMonitoring() {
        let available = AppFeature.keepAwake.isAvailable
        let selectedApps = Defaults.sanitizedBundleIdentifierList(
            UserDefaults.standard.stringArray(forKey: DefaultsKey.keepAwakeRunningAppBundleIDs) ?? [])
        if runningAppBundleIDs != selectedApps { runningAppBundleIDs = selectedApps }
        syncScreenLockMonitoring()
        let observeScreens = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeExternalDisplay)
        let observePower = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeConnectedToPower)
        let observeRunningApps = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeRunningApps)
            && !runningAppBundleIDs.isEmpty

        setScreenMonitoringEnabled(observeScreens)
        setPowerMonitoringEnabled(observePower)
        setRunningAppsMonitoringEnabled(observeRunningApps)
        evaluateAutomation()
    }

    func syncScreenLockMonitoring() {
        let enabled = AppFeature.keepAwake.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakePauseWhenLocked)
        let center = DistributedNotificationCenter.default()

        if enabled {
            guard screenLockObservers.isEmpty else { return }
            screenLockObservers = [
                center.addObserver(forName: Self.screenLockNotification,
                                   object: nil, queue: .main) { [weak self] _ in
                    self?.screenLockStateDidChange(locked: true)
                },
                center.addObserver(forName: Self.screenUnlockNotification,
                                   object: nil, queue: .main) { [weak self] _ in
                    self?.screenLockStateDidChange(locked: false)
                },
            ]
            screenLocked = KeepAwakeAutomationSupport.isScreenLocked(
                sessionDictionary: CGSessionCopyCurrentDictionary() as? [String: Any]
            )
            syncSessionWithScreenLock()
        } else {
            guard !screenLockObservers.isEmpty else { return }
            for observer in screenLockObservers { center.removeObserver(observer) }
            screenLockObservers.removeAll()
            screenLocked = false
            syncSessionWithScreenLock()
        }
    }

    func screenLockStateDidChange(locked: Bool) {
        guard screenLocked != locked else { return }
        screenLocked = locked
        syncSessionWithScreenLock()
        evaluateAutomation()
    }

    func syncSessionWithScreenLock() {
        guard isActive else {
            sessionPausedForScreenLock = false
            return
        }
        let shouldPause = screenLocked
            && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakePauseWhenLocked)
        guard shouldPause != sessionPausedForScreenLock else { return }

        if shouldPause {
            let released = releaseAssertions()
            sessionPausedForScreenLock = released
            assertionFailed = !released
            if clamshellNeedsRestore { disableClamshell(synchronous: false) }
            stopBatteryWatch()
            stopMouseJiggleTimer()
            return
        }

        sessionPausedForScreenLock = false
        if let endDate, endDate <= Date() {
            if !continueAutomaticallyAfterTimerIfNeeded() { deactivate(reason: .timer) }
            return
        }
        if sessionTrigger == .automation, !automationConditionsHold() {
            deactivate(reason: .manual)
            return
        }
        startBatteryWatch()
        guard isActive else { return }
        guard applyAssertions() else { deactivate(reason: .manual); return }
        syncMouseJiggleTimer()
        if clamshellPreferred { applyClamshellPreference() }
    }

    func setScreenMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            guard screenParametersObserver == nil else { return }
            screenParametersObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleAutomationEvaluation(after: 0.35)
            }
        } else if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
            lastExternalDisplayConnected = nil
        }
    }

    func setPowerMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            guard powerSourceRunLoopSource == nil else { return }
            let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                let manager = Unmanaged<KeepAwakeManager>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.scheduleAutomationEvaluation(after: 0.1)
                }
            }, context)?.takeRetainedValue()
            if let powerSourceRunLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
            }
        } else if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
            self.powerSourceRunLoopSource = nil
        }
    }

    func setRunningAppsMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            guard runningAppsObservation == nil else { return }
            // The running-apps list rather than launch and terminate
            // notifications: macOS posts neither for some background helper
            // apps nested in another app's bundle, while the list still gains
            // and loses them (#1468).
            runningAppsObservation = NSWorkspace.shared.observe(\.runningApplications) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.scheduleAutomationEvaluation(after: 0.1)
                }
            }
        } else {
            runningAppsObservation?.invalidate()
            runningAppsObservation = nil
        }
    }

}
