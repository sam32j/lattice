// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

/// Core of the energy feature: manages "keep awake" sessions through IOKit power
/// assertions, the closed-lid mode (pmset disablesleep, administrator password)
/// and the battery protection watchdog.
final class KeepAwakeManager: ObservableObject {
    static let shared = KeepAwakeManager()
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "lattice",
                                    category: "keep-awake")

    enum EndReason { case manual, timer, battery, quit }
    enum SessionTrigger { case manual, automation }

    @Published var assertionFailed = false
    @Published var isActive = false
    @Published var endDate: Date? // nil = indefinite
    @Published var sessionTrigger: SessionTrigger?
    /// The preset a manual session started from; nil for an end time or automation.
    @Published var sessionMinutes: Int?
    @Published var runningAppBundleIDs: [String] = []
    @Published var activeAutomationConditions = Set<KeepAwakeAutomationCondition>()
    @Published var clamshellActive = false {
        didSet {
            guard clamshellActive != oldValue else { return }
            syncLidDimmingObserver()
        }
    }
    @Published var passwordlessClamshell = false
    @Published var clamshellSetupInProgress = false
    @Published var clamshellSetupFailed = false

    /// Persistent preference: when on, every keep-awake session also disables
    /// lid sleep, and ending the session restores it — no per-session setup.
    @Published var clamshellPreferred: Bool {
        didSet {
            guard clamshellPreferred != oldValue else { return }
            UserDefaults.standard.set(clamshellPreferred, forKey: DefaultsKey.clamshellPreferred)
            clamshellSetupFailed = false
            guard !isTerminating else { return }
            if clamshellPreferred {
                if !sessionPausedForScreenLock { applyClamshellPreference() }
            } else if clamshellNeedsRestore {
                clamshellSetupInProgress = false
                clamshellSetupID = nil
                disableClamshell(synchronous: false)
            } else {
                clamshellSetupInProgress = false
                clamshellSetupID = nil
            }
        }
    }

    /// Persistent preference: dims the built-in display to zero while the
    /// closed-lid mode is actually in effect, restoring the captured
    /// brightness when the lid opens again.
    @Published var dimScreenOnLidClose: Bool {
        didSet {
            guard dimScreenOnLidClose != oldValue else { return }
            UserDefaults.standard.set(dimScreenOnLidClose, forKey: DefaultsKey.dimScreenOnLidClose)
            if !dimScreenOnLidClose { applyDimmingAction(LidDimmingSupport.restoring(saved: savedDisplayBrightness)) }
            syncLidDimmingObserver()
        }
    }

    var onSessionEnded: ((EndReason) -> Void)?

    let assertions = KeepAwakeAssertions()
    var stoppingSession = false
    var wakeObserver: NSObjectProtocol?
    var endTimer: Timer?
    var batteryTimer: Timer?
    var mouseJiggleTimer: Timer?
    var pendingMouseReturn: DispatchWorkItem?
    var defaultsObserver: AnyCancellable?
    var screenParametersObserver: NSObjectProtocol?
    var screenLockObservers: [NSObjectProtocol] = []
    var powerSourceRunLoopSource: CFRunLoopSource?
    var runningAppsObservation: NSKeyValueObservation?
    var automationEvaluationWorkItem: DispatchWorkItem?
    var lastExternalDisplayConnected: Bool?
    var screenLocked = false
    var sessionPausedForScreenLock = false
    var automationSuppressedUntilConditionsClear = false
    var recoveryCompleted = false
    var isTerminating = false
    var clamshellEnablePending = false
    var clamshellRestorePending = false
    var clamshellOperationGeneration = 0
    var clamshellSetupID: UUID?
    var lidSleepGeneration = 0
    var lidSleepAttemptsRemaining = 0
    var lidDimmingNotificationPort: IONotificationPortRef?
    var lidDimmingNotification: io_object_t = 0
    var lidClosedForDimming: Bool?
    var savedDisplayBrightness: Double?
    static let screenLockNotification = Notification.Name("com.apple.screenIsLocked")
    static let screenUnlockNotification = Notification.Name("com.apple.screenIsUnlocked")
    /// Guards the closed-lid setup against an infinite retry loop: if `pmset
    /// disablesleep` keeps failing while the sudoers rule still checks out as
    /// installed, re-preparing would bounce here forever (and flicker the
    /// caption). One automatic re-acquire per user attempt, then we give up.
    var clamshellSetupRetried = false
    /// A reply to a settings change already waiting for the next run loop turn.
    var preferenceSyncScheduled = false

    private init() {
        clamshellPreferred = UserDefaults.standard.bool(forKey: DefaultsKey.clamshellPreferred)
        dimScreenOnLidClose = UserDefaults.standard.bool(forKey: DefaultsKey.dimScreenOnLidClose)
    }
}
