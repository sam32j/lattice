import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

extension KeepAwakeManager {
    // MARK: - Closed lid (pmset disablesleep)

    var clamshellNeedsRestore: Bool {
        clamshellActive || clamshellEnablePending || clamshellRestorePending
            || UserDefaults.standard.bool(forKey: DefaultsKey.sleepDisabledFlag)
    }

    func applyClamshellPreference() {
        guard !isTerminating, !clamshellRestorePending else { return }
        // A fresh user-driven attempt (toggle on, or a new session) gets one
        // automatic setup retry again.
        clamshellSetupRetried = false
        if passwordlessClamshell {
            if isActive, !sessionPausedForScreenLock {
                enableClamshell()
            }
        } else {
            prepareClamshellPreference()
        }
    }

    func prepareClamshellPreference() {
        guard !isTerminating, !clamshellRestorePending,
              clamshellPreferred, !clamshellSetupInProgress else { return }
        let requestID = UUID()
        clamshellSetupID = requestID
        clamshellSetupInProgress = true
        clamshellSetupFailed = false

        DispatchQueue.global(qos: .userInitiated).async {
            let configured = Sudoers.isConfigured()
            DispatchQueue.main.async {
                guard !self.isTerminating, self.clamshellSetupID == requestID else { return }
                if configured {
                    self.finishClamshellSetup(ok: true, requestID: requestID)
                } else {
                    Sudoers.install { ok in
                        DispatchQueue.main.async {
                            self.finishClamshellSetup(ok: ok, requestID: requestID)
                        }
                    }
                }
            }
        }
    }

    func finishClamshellSetup(ok: Bool, requestID: UUID) {
        guard !isTerminating, clamshellSetupID == requestID else { return }
        clamshellSetupID = nil
        clamshellSetupInProgress = false
        passwordlessClamshell = ok

        guard ok else {
            markClamshellSetupFailed()
            return
        }

        if isActive, clamshellPreferred, !sessionPausedForScreenLock {
            enableClamshell()
        }
    }

    /// Turns the preference back off and surfaces the error, ending any retry
    /// loop. Setting `clamshellPreferred` false runs its `didSet`, which clears
    /// the in-progress/failed flags, so the failure flag is raised afterwards.
    func markClamshellSetupFailed() {
        clamshellSetupInProgress = false
        guard clamshellPreferred else { return }
        clamshellPreferred = false
        clamshellSetupFailed = true
    }

    func enableClamshell() {
        guard !isTerminating, isActive, clamshellPreferred, !sessionPausedForScreenLock,
              !clamshellActive, !clamshellEnablePending, !clamshellRestorePending else { return }
        clamshellOperationGeneration &+= 1
        let generation = clamshellOperationGeneration
        clamshellEnablePending = true
        // Persist before submitting the write: quitting or crashing before
        // its reply must not leave an unrecorded system-wide sleep override.
        UserDefaults.standard.set(true, forKey: DefaultsKey.sleepDisabledFlag)
        Sudoers.pmsetDisableSleep(true) { ok in
            DispatchQueue.main.async {
                guard !self.isTerminating, self.clamshellOperationGeneration == generation else { return }
                self.clamshellEnablePending = false
                guard ok else {
                    // Repair the passwordless path once per deliberate attempt.
                    self.passwordlessClamshell = false
                    guard self.isActive, self.clamshellPreferred, !self.sessionPausedForScreenLock else { return }
                    if self.clamshellSetupRetried {
                        self.markClamshellSetupFailed()
                    } else {
                        self.clamshellSetupRetried = true
                        self.prepareClamshellPreference()
                    }
                    return
                }
                self.passwordlessClamshell = true
                if self.isActive, self.clamshellPreferred, !self.sessionPausedForScreenLock {
                    self.clamshellActive = true
                } else {
                    self.disableClamshell(synchronous: false)
                }
            }
        }
    }

    func disableClamshell(synchronous: Bool) {
        // A new session waits for an outstanding restore, including its
        // authorization fallback, so an old off cannot overwrite a new on.
        guard synchronous || !clamshellRestorePending else { return }
        clamshellSetupID = nil
        clamshellSetupInProgress = false
        clamshellOperationGeneration &+= 1
        let generation = clamshellOperationGeneration
        lidSleepGeneration &+= 1
        lidSleepAttemptsRemaining = 0
        clamshellActive = false
        clamshellEnablePending = false
        clamshellRestorePending = true
        if synchronous {
            // This drains earlier native writes, including a pending enable.
            // Complete here: no main-queue callback survives process teardown.
            let ok = Sudoers.pmsetDisableSleep(false)
            finishClamshellRestore(ok: ok, usedPasswordless: true,
                                  generation: generation, synchronous: true)
        } else {
            Sudoers.pmsetDisableSleep(false) { ok in
                DispatchQueue.main.async {
                    guard !self.isTerminating, self.clamshellOperationGeneration == generation else { return }
                    if ok {
                        self.finishClamshellRestore(ok: true, usedPasswordless: true,
                                                   generation: generation, synchronous: false)
                    } else {
                        // Never wait for a prompt on Sudoers' native queue:
                        // quit drains that queue while running on the main thread.
                        Sudoers.restoreSleepWithAuthorization(
                            prompt: L10n.shared.s.adminPromptClamshellOff,
                            shouldProceed: { !self.isTerminating && self.clamshellOperationGeneration == generation }
                        ) { restored in
                            DispatchQueue.main.async {
                                guard !self.isTerminating else { return }
                                self.finishClamshellRestore(ok: restored, usedPasswordless: false,
                                                           generation: generation, synchronous: false)
                            }
                        }
                    }
                }
            }
        }
    }

    func finishClamshellRestore(ok: Bool, usedPasswordless: Bool,
                                        generation: Int, synchronous: Bool) {
        guard clamshellOperationGeneration == generation else { return }
        clamshellRestorePending = false
        if !usedPasswordless { passwordlessClamshell = false }
        // Keep the recovery marker on failure; never request sleep while the
        // system-wide override may still be set.
        guard ok else { return }
        UserDefaults.standard.set(false, forKey: DefaultsKey.sleepDisabledFlag)
        if !isTerminating, isActive, clamshellPreferred, !sessionPausedForScreenLock {
            enableClamshell()
        } else {
            sleepIfLidAlreadyClosed(synchronous: synchronous)
        }
    }

    /// Clearing `disablesleep` only clears a kernel flag. macOS evaluates the
    /// lid when it opens or closes, so a lid that shut during the session is
    /// never looked at again and the Mac stays awake until the battery runs
    /// out (#1729). Request the sleep that closing the lid would have caused.
    /// `pmset` returns before powerd has handed the cleared flag to the
    /// kernel, which refuses sleep until it has, so a refusal is retried.
    func sleepIfLidAlreadyClosed(attemptsLeft: Int = 10, synchronous: Bool = false,
                                          generation: Int? = nil) {
        let generation = generation ?? lidSleepGeneration
        guard generation == lidSleepGeneration else { return }
        lidSleepAttemptsRemaining = 0
        guard !isActive || sessionPausedForScreenLock, !clamshellActive else { return }
        guard BrightnessService.lidClosed() == true, Self.lidSleepIsAllowed() else { return }
        let rootDomain = IOPMFindPowerManagement(kIOMainPortDefault)
        guard rootDomain != 0 else { return }
        let result = IOPMSleepSystem(rootDomain)
        IOServiceClose(rootDomain)
        guard result != kIOReturnSuccess, attemptsLeft > 1 else { return }
        if synchronous {
            // The existing bounded retry must finish before quit returns.
            // Re-read the lid and external protections after every refusal.
            Thread.sleep(forTimeInterval: 0.5)
            sleepIfLidAlreadyClosed(attemptsLeft: attemptsLeft - 1, synchronous: true,
                                    generation: generation)
        } else {
            lidSleepAttemptsRemaining = attemptsLeft - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, !self.isTerminating else { return }
                self.sleepIfLidAlreadyClosed(attemptsLeft: attemptsLeft - 1, generation: generation)
            }
        }
    }

    static func lidSleepIsAllowed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let allowsSleep = IORegistryEntryCreateCFProperty(
            service, kAppleClamshellCausesSleepKey as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool
        guard allowsSleep == true else { return false }

        // The kernel does not republish its lid policy for every assertion
        // change. Read live protections as well, especially display hot-plug.
        var snapshot: Unmanaged<CFDictionary>?
        let result = IOPMCopyAssertionsByProcess(&snapshot)
        let values = snapshot?.takeRetainedValue()
        guard result == kIOReturnSuccess,
              let assertions = values as? [AnyHashable: [[String: Any]]]
        else { return false }
        return KeepAwakeAutomationSupport.lidSleepIsAllowed(
            systemAllowsSleep: allowsSleep, assertions: assertions.values.flatMap { $0 })
    }

}
