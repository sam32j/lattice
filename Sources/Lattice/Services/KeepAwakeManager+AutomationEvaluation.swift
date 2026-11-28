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
        if !liveAutomationConditions.isEmpty { liveAutomationConditions.removeAll() }
    }

    func evaluateAutomation() {
        guard recoveryCompleted, !isTerminating else { return }
        let enabled = currentEnabledAutomationConditions()
        let matches = currentMatchingAutomationConditions(enabled: enabled)
        if liveAutomationConditions != matches { liveAutomationConditions = matches }
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

        let available = AppFeature.keepAwake.isAvailable
        let automaticSessionActive = isActive && sessionTrigger == .automation
        let effectiveMatches = available && automaticSessionActive
            ? activeAutomationMatches(matches, enabled: enabled) : matches
        if screenLocked,
           UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakePauseWhenLocked) {
            waitingForPower = false
            return
        }
        if powerDisconnectEvaluation != nil, batteryProtectionPercent() != nil {
            deactivate(reason: .battery)
            return
        }
        let action = KeepAwakeAutomationSupport.action(
            featureAvailable: available,
            matchingConditions: effectiveMatches,
            enabledConditions: enabled,
            requireAll: requireAll,
            sessionActive: isActive,
            automaticSessionActive: automaticSessionActive
        )
        switch action {
        case .none:
            // An active automatic session survives unsatisfied real rules only
            // when the power delay supplies the missing match.
            if automaticSessionActive { waitingForPower = !satisfied }
        case .activate:
            guard automaticSessionAllowedByBatteryProtection() else { return }
            activeAutomationConditions = matches
            activate(end: nil, trigger: .automation)
        case .deactivate:
            deactivate(reason: .manual)
        }
    }

    var powerDisconnectDelay: Int {
        Defaults.sanitizedKeepAwakePowerDisconnectDelay(
            UserDefaults.standard.integer(forKey: DefaultsKey.keepAwakePowerDisconnectDelay)
        )
    }

    func activeAutomationMatches(_ matches: Set<KeepAwakeAutomationCondition>,
                                 enabled: Set<KeepAwakeAutomationCondition>)
        -> Set<KeepAwakeAutomationCondition> {
        let deadline = powerDisconnectGrace.deadline(
            powerEnabled: enabled.contains(.power),
            wasOnPower: activeAutomationConditions.contains(.power),
            onPower: matches.contains(.power),
            delaySeconds: powerDisconnectDelay
        )
        activeAutomationConditions = matches
        if powerDisconnectEvaluation?.deadline != deadline {
            powerDisconnectEvaluation?.task.cancel()
            powerDisconnectEvaluation = deadline.map { deadline in
                let task = Task { @MainActor [weak self] in
                    try? await Task.sleep(until: deadline, clock: .continuous)
                    guard !Task.isCancelled else { return }
                    self?.evaluateAutomation()
                }
                return (deadline, task)
            }
        }
        // Only Power gets a grace period. All still needs every other condition.
        return deadline == nil ? matches : matches.union([.power])
    }

    func clearPowerDisconnectGrace() {
        waitingForPower = false
        powerDisconnectGrace = KeepAwakePowerDisconnectGrace()
        powerDisconnectEvaluation?.task.cancel()
        powerDisconnectEvaluation = nil
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
    func automationConditionsHold(includingPowerDelay: Bool = false) -> Bool {
        let enabled = currentEnabledAutomationConditions()
        let matches = currentMatchingAutomationConditions(enabled: enabled)
        return KeepAwakeAutomationSupport.conditionsSatisfied(
            matching: includingPowerDelay ? activeAutomationMatches(matches, enabled: enabled) : matches,
            enabled: enabled,
            requireAll: automationRequiresAllConditions())
    }

    func currentMatchingAutomationConditions(enabled: Set<KeepAwakeAutomationCondition>)
        -> Set<KeepAwakeAutomationCondition> {
        let powerEnabled = enabled.contains(.power)
        let connectedToPower = powerEnabled && SystemInfo.batterySnapshot()?.isOnExternalPower == true

        let externalDisplayEnabled = enabled.contains(.externalDisplay)
        let externalDisplayConnected: Bool
        if externalDisplayEnabled {
            if let current = Self.hasExternalDisplay() {
                lastExternalDisplayConnected = current
            }
            externalDisplayConnected = lastExternalDisplayConnected ?? false
        } else {
            externalDisplayConnected = false
        }

        let runningAppsEnabled = enabled.contains(.runningApps)
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
        let enabled = currentEnabledAutomationConditions()
        let matches = currentMatchingAutomationConditions(enabled: enabled)
        guard KeepAwakeAutomationSupport.conditionsSatisfied(
                matching: matches,
                enabled: enabled,
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
