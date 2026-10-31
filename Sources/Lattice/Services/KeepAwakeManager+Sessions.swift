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
            if sessionTrigger == .automation || automationConditionsHold() {
                automationSuppressedUntilConditionsClear = true
            }
            deactivate(reason: .manual)
        } else {
            startLastPick()
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
        activate(end: end, trigger: .manual)
        sessionMinutes = isActive ? minutes : nil
        guard isActive else { return }
        // Every entry point records the pick, so each switch restarts the same session.
        UserDefaults.standard.set(minutes, forKey: DefaultsKey.defaultDuration)
        UserDefaults.standard.set(false, forKey: DefaultsKey.keepAwakeSwitchUsesUntil)
    }

    func activate(until date: Date) {
        guard date > Date() else { return }
        automationSuppressedUntilConditionsClear = false
        activate(end: date, trigger: .manual)
        // An end time replaces any running preset, so no duration chip stays selected.
        sessionMinutes = nil
        guard isActive else { return }
        UserDefaults.standard.set(true, forKey: DefaultsKey.keepAwakeSwitchUsesUntil)
        UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: DefaultsKey.keepAwakeUntilTime)
    }

    /// Restarts the last pick: the saved end time while it is still ahead,
    /// otherwise the saved duration. A passed end time never rolls to
    /// tomorrow here, which would silently start a session of almost a day.
    func startLastPick() {
        let defaults = UserDefaults.standard
        let end = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: DefaultsKey.keepAwakeUntilTime))
        if defaults.bool(forKey: DefaultsKey.keepAwakeSwitchUsesUntil), end > Date() {
            activate(until: end)
        } else {
            activate(minutes: Defaults.sanitizedDefaultDuration(defaults.integer(forKey: DefaultsKey.defaultDuration)))
        }
    }

    func activate(end: Date?, trigger: SessionTrigger) {
        guard !isTerminating, AppFeature.keepAwake.isAvailable else { return }
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
        if trigger == .manual {
            activeAutomationConditions.removeAll()
        }
        isActive = true
        if let end {
            endDate = end
            scheduleEnd(at: end)
        } else {
            endDate = nil
        }
        if !sessionPausedForScreenLock { startBatteryWatch() }
        syncMouseJiggleTimer()
        if clamshellPreferred, !sessionPausedForScreenLock {
            applyClamshellPreference()
        }
    }

    func activateOnLaunchIfNeeded() {
        guard AppFeature.keepAwake.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeAutoStart),
              !isActive else { return }
        activate(minutes: Defaults.sanitizedDefaultDuration(
            UserDefaults.standard.integer(forKey: DefaultsKey.defaultDuration)))
    }

    func extend(minutes: Int) {
        guard isActive, let current = endDate else { return }
        let newEnd = HubStayAwakeSupport.durationEnd(minutes: minutes, isTimed: true, end: current, now: Date())
        endDate = newEnd
        scheduleEnd(at: newEnd)
    }

    func deactivate(reason: EndReason) {
        let hadSession = isActive
        if reason == .quit {
            isTerminating = true
            stopPreferenceObservation()
            clamshellSetupID = nil
            clamshellSetupInProgress = false
            stopAutomationMonitoring()
        }
        endTimer?.invalidate()
        endTimer = nil
        let released = releaseAssertions()
        if released && stoppingSession { assertionFailed = false }
        stoppingSession = !released && reason != .quit
        if !released { assertionFailed = true }
        endDate = nil
        sessionTrigger = nil
        sessionMinutes = nil
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
