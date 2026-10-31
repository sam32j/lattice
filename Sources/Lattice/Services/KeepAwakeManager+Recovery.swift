import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

extension KeepAwakeManager {
    /// If the app died unexpectedly while sleep was disabled, restores normal
    /// behavior on the next launch.
    func recoverIfNeeded(completion: (() -> Void)? = nil) {
        guard !isTerminating else { return }
        recoverDimmedDisplayIfNeeded()
        guard UserDefaults.standard.bool(forKey: DefaultsKey.sleepDisabledFlag) else {
            finishRecovery(completion)
            return
        }
        // A manual session may start while launch recovery is asking for
        // authorization. Its enable must wait until that older off is done.
        clamshellSetupID = nil
        clamshellSetupInProgress = false
        clamshellOperationGeneration &+= 1
        let generation = clamshellOperationGeneration
        clamshellRestorePending = true
        let finish: (Bool) -> Void = { ok in
            guard !self.isTerminating, self.clamshellOperationGeneration == generation else { return }
            self.clamshellRestorePending = false
            if ok { UserDefaults.standard.set(false, forKey: DefaultsKey.sleepDisabledFlag) }
            self.finishRecovery(completion)
            if ok, self.isActive, self.clamshellPreferred, !self.sessionPausedForScreenLock {
                self.enableClamshell()
            }
        }
        DispatchQueue.global(qos: .utility).async {
            let report = Shell.run("/usr/bin/pmset", ["-g"])
            let stillDisabled = SudoersSupport.sleepDisabled(inPmsetOutput: report.output)
            // An unreadable report is not evidence that a persisted override
            // has disappeared. Keep its recovery marker unless an off succeeds.
            if report.status == 0, !stillDisabled {
                DispatchQueue.main.async { finish(true) }
            } else if Sudoers.pmsetDisableSleep(false) {
                DispatchQueue.main.async { finish(true) }
            } else {
                DispatchQueue.main.async {
                    guard !self.isTerminating, self.clamshellOperationGeneration == generation else { return }
                    Sudoers.restoreSleepWithAuthorization(
                        prompt: L10n.shared.s.adminPromptRecover,
                        shouldProceed: { !self.isTerminating && self.clamshellOperationGeneration == generation }
                    ) { ok in
                        DispatchQueue.main.async { finish(ok) }
                    }
                }
            }
        }
    }

    func finishRecovery(_ completion: (() -> Void)?) {
        guard !isTerminating else { return }
        recoveryCompleted = true
        completion?()
        syncWithPreferences()
    }

    /// A crash or force quit while the lid was closed can leave the built-in
    /// panel dimmed with nothing left running to bring it back. Closed-lid
    /// sleep already recovers its own override the same way: the intent is
    /// written down before acting, and undone on the next launch.
    func recoverDimmedDisplayIfNeeded() {
        guard let saved = UserDefaults.standard.object(forKey: DefaultsKey.dimmedDisplaySavedBrightness) as? Double
        else { return }
        // Set before attempting, not just on failure: if the write does not
        // report success until later, `syncLidDimmingObserver` still has to
        // see this as owed right away to arm the lid observer for a retry.
        savedDisplayBrightness = saved
        applyDimmingAction(.restore(saved))
        syncLidDimmingObserver()
    }

}
