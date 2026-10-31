import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

extension KeepAwakeManager {
    func scheduleAutomationEvaluation(after delay: TimeInterval) {
        automationEvaluationWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.automationEvaluationWorkItem = nil
            self?.evaluateAutomation()
        }
        automationEvaluationWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func stopAutomationMonitoring() {
        automationEvaluationWorkItem?.cancel()
        automationEvaluationWorkItem = nil
        setScreenMonitoringEnabled(false)
        setPowerMonitoringEnabled(false)
        setRunningAppsMonitoringEnabled(false)
        let center = DistributedNotificationCenter.default()
        for observer in screenLockObservers { center.removeObserver(observer) }
        screenLockObservers.removeAll()
        screenLocked = false
        sessionPausedForScreenLock = false
        activeAutomationConditions.removeAll()
    }

    func evaluateAutomation() {
        guard recoveryCompleted, !isTerminating else { return }
        let matches = currentMatchingAutomationConditions()
        let enabled = currentEnabledAutomationConditions()
        let requireAll = automationRequiresAllConditions()
        let satisfied = KeepAwakeAutomationSupport.conditionsSatisfied(
            matching: matches, enabled: enabled, requireAll: requireAll)

        if automationSuppressedUntilConditionsClear {
            if !satisfied {
                automationSuppressedUntilConditionsClear = false
            }
            if sessionTrigger == .automation {
                deactivate(reason: .manual)
            }
            return
        }

        if screenLocked,
           UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakePauseWhenLocked) {
            if sessionTrigger == .automation { activeAutomationConditions = matches }
            return
        }

        if sessionTrigger == .automation {
            activeAutomationConditions = matches
        }
        let action = KeepAwakeAutomationSupport.action(
            featureAvailable: AppFeature.keepAwake.isAvailable,
            matchingConditions: matches,
            enabledConditions: enabled,
            requireAll: requireAll,
            sessionActive: isActive,
            automaticSessionActive: isActive && sessionTrigger == .automation
        )
        switch action {
        case .none:
            break
        case .activate:
            guard automaticSessionAllowedByBatteryProtection() else { return }
            activeAutomationConditions = matches
            activate(end: nil, trigger: .automation)
        case .deactivate:
            deactivate(reason: .manual)
        }
    }

    func automationRequiresAllConditions() -> Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeAutomationRequireAll)
    }

    func currentEnabledAutomationConditions() -> Set<KeepAwakeAutomationCondition> {
        KeepAwakeAutomationSupport.enabledConditions(
            externalDisplayEnabled: UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeExternalDisplay),
            powerEnabled: UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeConnectedToPower),
            runningAppsEnabled: UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeRunningApps),
            hasSelectedApps: !runningAppBundleIDs.isEmpty
        )
    }

    /// Whether the automation currently asks for a session, in either match
    /// mode. Every caller that used to read "any condition matches" has to ask
    /// this instead: under All, a session that stops being wanted still has a
    /// non-empty matching set (issue #1587).
    func automationConditionsHold() -> Bool {
        KeepAwakeAutomationSupport.conditionsSatisfied(
            matching: currentMatchingAutomationConditions(),
            enabled: currentEnabledAutomationConditions(),
            requireAll: automationRequiresAllConditions())
    }

    func currentMatchingAutomationConditions() -> Set<KeepAwakeAutomationCondition> {
        let externalDisplayEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeExternalDisplay)
        let externalDisplayConnected: Bool
        if externalDisplayEnabled {
            if let current = Self.hasExternalDisplay() {
                lastExternalDisplayConnected = current
            }
            externalDisplayConnected = lastExternalDisplayConnected ?? false
        } else {
            externalDisplayConnected = false
        }

        let powerEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeConnectedToPower)
        let connectedToPower = powerEnabled
            && (SystemInfo.batterySnapshot().map { !$0.isOnBattery } ?? false)

        let runningAppsEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeRunningApps)
        let selectedAppsRunning: Bool
        if runningAppsEnabled, !runningAppBundleIDs.isEmpty {
            let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
            selectedAppsRunning = KeepAwakeAutomationSupport.selectedAppsAreRunning(
                selectedBundleIDs: runningAppBundleIDs,
                runningBundleIDs: running
            )
        } else {
            selectedAppsRunning = false
        }

        return KeepAwakeAutomationSupport.matchingConditions(
            externalDisplayEnabled: externalDisplayEnabled,
            externalDisplayConnected: externalDisplayConnected,
            powerEnabled: powerEnabled,
            connectedToPower: connectedToPower,
            runningAppsEnabled: runningAppsEnabled,
            selectedAppsRunning: selectedAppsRunning
        )
    }

    static func hasExternalDisplay() -> Bool? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success else { return nil }
        guard count > 0 else { return false }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return nil }
        let builtInFlags = displays.prefix(Int(count)).map { CGDisplayIsBuiltin($0) != 0 }
        return KeepAwakeAutomationSupport.hasExternalDisplay(builtInFlags: builtInFlags)
    }

    func automaticSessionAllowedByBatteryProtection() -> Bool {
        let limit = Defaults.sanitizedBatteryLimit(
            UserDefaults.standard.integer(forKey: DefaultsKey.batteryLimit)
        )
        guard limit > 0,
              let battery = SystemInfo.batterySnapshot(),
              battery.isOnBattery else { return true }
        return battery.percent > limit
    }

    func continueAutomaticallyAfterTimerIfNeeded() -> Bool {
        guard sessionTrigger == .manual,
              AppFeature.keepAwake.isAvailable,
              !automationSuppressedUntilConditionsClear,
              automaticSessionAllowedByBatteryProtection() else { return false }
        // The same full match the automation itself would need to start a
        // session: under All, a timed session must not be handed over on one
        // condition the automation would never have acted on (issue #1587).
        let matches = currentMatchingAutomationConditions()
        guard KeepAwakeAutomationSupport.conditionsSatisfied(
                matching: matches,
                enabled: currentEnabledAutomationConditions(),
                requireAll: automationRequiresAllConditions()) else { return false }
        activeAutomationConditions = matches
        activate(end: nil, trigger: .automation)
        return true
    }

    func scheduleEnd(at date: Date) {
        endTimer?.invalidate()
        let t = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            if !self.continueAutomaticallyAfterTimerIfNeeded() {
                self.deactivate(reason: .timer)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        endTimer = t
    }

}
