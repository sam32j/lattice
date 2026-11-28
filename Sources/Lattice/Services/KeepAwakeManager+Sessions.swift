import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

extension KeepAwakeManager {
    /// Refreshes (in the background) whether the closed-lid sudoers rule is installed.
    func refreshPasswordlessStatus() {
        guard !isTerminating, !clamshellRestorePending else { return }
        let generation = clamshellOperationGeneration
        DispatchQueue.global(qos: .utility).async {
            let configured = Sudoers.isConfigured()
            DispatchQueue.main.async {
                guard !self.isTerminating, !self.clamshellRestorePending,
                      self.clamshellOperationGeneration == generation else { return }
                self.passwordlessClamshell = configured
            }
        }
    }

    /// Clearing permissions, or an uninstall that stopped, restored normal
    /// sleep directly and left this app running. Discard the old session state
    /// without asking for the rule again: a rule that is still installed rearms
    /// the current session, and a removed one is requested by the next session.
    func resumeAfterSystemTeardown() {
        let restorePending = clamshellRestorePending
        if !restorePending { clamshellOperationGeneration &+= 1 }
        // An installation prompt may already be open. Its existing reply can
        // finish setup without showing a second authorization request.
        clamshellEnablePending = false
        lidSleepGeneration &+= 1
        lidSleepAttemptsRemaining = 0
        clamshellActive = false
        passwordlessClamshell = false
        let generation = clamshellOperationGeneration
        let checksSleep = UserDefaults.standard.bool(forKey: DefaultsKey.sleepDisabledFlag)
        DispatchQueue.global(qos: .utility).async {
            // A session can start while the removal waits for its password and
            // turn sleep off again through the rule. Only a reading that answered
            // "on" lets the recovery marker go.
            var sleepRestored = true
            if checksSleep {
                let report = Shell.run("/usr/bin/pmset", ["-g"])
                sleepRestored = report.status == 0
                    && !SudoersSupport.sleepDisabled(inPmsetOutput: report.output)
            }
            let configured = !restorePending && Sudoers.isConfigured()
            DispatchQueue.main.async {
                guard !self.isTerminating, self.clamshellOperationGeneration == generation else { return }
                if checksSleep, sleepRestored {
                    UserDefaults.standard.set(false, forKey: DefaultsKey.sleepDisabledFlag)
                }
                // A prior restore can still finish with an authorized off. Its
                // reply rearms this session in order after that operation.
                guard !restorePending, !self.clamshellRestorePending else { return }
                self.passwordlessClamshell = configured
                if configured, self.clamshellPreferred, AppFeature.keepAwake.isAvailable {
                    self.enableClamshell()
                }
            }
        }
    }

    // MARK: - Session

    func toggle() {
        assertionFailed = false
        if isActive {
            // A session can outlive its last real match while waiting for power.
            // In that case the next connection is a new activation.
            automationSuppressedUntilConditionsClear = automationConditionsHold()
            deactivate(reason: .manual)
        } else {
            startDefault()
        }
    }

    /// Disabling keeps saved duration and shortcut preferences for the next activation.
    /// Leave Stop and the failure state reachable if native assertions cannot release.
    func prepareForFeatureDisable() -> Bool {
        deactivate(reason: .manual)
        return !isActive
    }

    func syncWithFeatures() {
        syncWithPreferences()
    }

    func syncWithPreferences() {
        guard !isTerminating else { return }
        guard AppFeature.keepAwake.isAvailable else {
            stopPreferenceObservation()
            stopAutomationMonitoring()
            stopMouseJiggleTimer()
            if isActive || clamshellNeedsRestore { deactivate(reason: .manual) }
            return
        }
        startPreferenceObservation()
        if stoppingSession { deactivate(reason: .manual); return }
        syncAutomationMonitoring()
        if screenLocked, UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakePauseWhenLocked) {
            syncSessionWithScreenLock()
            return
        }
        if isActive, !sessionPausedForScreenLock, !applyAssertions() {
            deactivate(reason: .manual)
        }
        syncMouseJiggleTimer()
    }

    /// Called by automation controls so a deliberate preference change can
    /// resume evaluation after a manually stopped automatic session.
    func automationPreferencesDidChange() {
        automationSuppressedUntilConditionsClear = false
        syncWithPreferences()
    }

    /// `minutes <= 0` activates indefinitely.
    func activate(minutes: Int) {
        automationSuppressedUntilConditionsClear = false
        let minutes = Defaults.sanitizedDefaultDuration(minutes)
        let end = minutes > 0 ? Date().addingTimeInterval(TimeInterval(minutes) * 60) : nil
        activate(end: end, trigger: .manual, minutes: minutes)
    }

    func activate(until date: Date) {
        guard date > Date() else { return }
        automationSuppressedUntilConditionsClear = false
        // An end time replaces any running preset, so no duration chip stays selected.
        activate(end: date, trigger: .manual)
    }

    /// Starts the default duration, the one setting the shortcut, the menu
    /// bar icon and `toggle()` share. Starting a session anywhere else never
    /// changes it, so the Default duration menu always shows what was chosen.
    func startDefault() {
        activate(minutes: Defaults.sanitizedDefaultDuration(
            UserDefaults.standard.integer(forKey: DefaultsKey.defaultDuration)))
    }

    func activate(end: Date?, trigger: SessionTrigger, minutes: Int? = nil) {
        guard !isTerminating, AppFeature.keepAwake.isAvailable else { return }
        clearPowerDisconnectGrace()
        lidSleepGeneration &+= 1
        lidSleepAttemptsRemaining = 0
        endTimer?.invalidate()
        endTimer = nil
        syncScreenLockMonitoring()
        sessionPausedForScreenLock = screenLocked
            && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakePauseWhenLocked)
        if sessionPausedForScreenLock {
            guard releaseAssertions() else {
                assertionFailed = true
                deactivate(reason: .manual)
                return
            }
            assertionFailed = false
        }
        if !sessionPausedForScreenLock, !applyAssertions() {
            deactivate(reason: .manual)
            return
        }
        stoppingSession = false
        sessionTrigger = trigger
        sessionMinutes = minutes
        if trigger == .manual {
            activeAutomationConditions.removeAll()
        }
        isActive = true
        // The ring's whole: a new session starts it over, and extending one
        // moves only its end, so the total grows with it.
        sessionStartDate = Date()
        if let end {
            endDate = end
            scheduleEnd(at: end)
        } else {
            endDate = nil
        }
        if trigger == .manual {
            saveManualSession()
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.keepAwakeSessionEnd)
        }
        if !sessionPausedForScreenLock { startBatteryWatch() }
        guard isActive else { return }
        syncMouseJiggleTimer()
        if clamshellPreferred, !sessionPausedForScreenLock {
            applyClamshellPreference()
        }
    }

    func extend(minutes: Int) {
        guard isActive, let current = endDate else { return }
        let newEnd = HubStayAwakeSupport.durationEnd(minutes: minutes, isTimed: true, end: current, now: Date())
        endDate = newEnd
        scheduleEnd(at: newEnd)
        if sessionTrigger == .manual { saveManualSession() }
    }

    /// Records the running manual session so a relaunch, restart or crash
    /// can pick it up. The default duration can change while it runs, so the
    /// preset is stored with it.
    func saveManualSession() {
        var record: [String: Any] = ["end": endDate?.timeIntervalSinceReferenceDate ?? 0.0]
        if let sessionMinutes { record["minutes"] = sessionMinutes }
        UserDefaults.standard.set(record, forKey: DefaultsKey.keepAwakeSessionEnd)
    }

    /// Picks up the manual session that was running when the app last quit,
    /// restarted or crashed. A timed one resumes with the time it has left;
    /// one whose end passed while the app was closed stays ended.
    func restoreSessionIfNeeded() {
        let defaults = UserDefaults.standard
        guard let saved = defaults.object(forKey: DefaultsKey.keepAwakeSessionEnd) else { return }
        guard AppFeature.keepAwake.isAvailable, !isActive,
              let record = saved as? [String: Any], let stored = record["end"] as? Double,
              stored == 0 || (stored > Date.timeIntervalSinceReferenceDate
                              && stored <= Date.distantFuture.timeIntervalSinceReferenceDate) else {
            // A session started during recovery already wrote its own record.
            if !isActive { defaults.removeObject(forKey: DefaultsKey.keepAwakeSessionEnd) }
            return
        }
        let end = stored == 0 ? nil : Date(timeIntervalSinceReferenceDate: stored)
        let minutes = end == nil ? 0 : record["minutes"] as? Int
        activate(end: end, trigger: .manual, minutes: minutes)
    }

    func deactivate(reason: EndReason) {
        let hadSession = isActive
        clearPowerDisconnectGrace()
        if reason == .quit {
            isTerminating = true
            stopPreferenceObservation()
            clamshellSetupID = nil
            clamshellSetupInProgress = false
            stopAutomationMonitoring()
        }
        endTimer?.invalidate()
        endTimer = nil
        // Quitting keeps the record so the next launch resumes the session;
        // every other end, the user's own included, is final.
        if reason != .quit {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.keepAwakeSessionEnd)
        }
        let released = releaseAssertions()
        if released && stoppingSession { assertionFailed = false }
        stoppingSession = !released && reason != .quit
        if !released { assertionFailed = true }
        endDate = nil
        sessionTrigger = nil
        sessionMinutes = nil
        sessionStartDate = nil
        activeAutomationConditions.removeAll()
        isActive = stoppingSession
        sessionPausedForScreenLock = false
        stopBatteryWatch()
        stopMouseJiggleTimer()
        // An enable can still be on the serialized native queue even though
        // its main-thread reply has not marked the session active yet.
        if clamshellNeedsRestore {
            disableClamshell(synchronous: reason == .quit)
        } else if reason == .quit, lidSleepAttemptsRemaining > 0 {
            sleepIfLidAlreadyClosed(attemptsLeft: lidSleepAttemptsRemaining, synchronous: true)
        }
        if released, hadSession, reason != .quit, reason != .manual {
            onSessionEnded?(reason)
        }
    }

}
