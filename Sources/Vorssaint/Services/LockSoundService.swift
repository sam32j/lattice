// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AppKit
import CoreGraphics

/// Session sounds have no dependency on island presentation or Accessibility.
final class LockSoundService {
    static let shared = LockSoundService()

    struct State {
        var locked = false
        var onConsole = true
        var sleeping = false
        var displaysSleeping = false
        var screenSaverRunning = false
    }

    private let defaults: UserDefaults
    private let workspace: NotificationCenter
    private let distributed: NotificationCenter
    private let initialState: () -> State
    private let play: (Bool) -> Void
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var preferenceObserver: NSObjectProtocol?
    private var state = State()

    init(defaults: UserDefaults = .standard,
         workspace: NotificationCenter = NSWorkspace.shared.notificationCenter,
         distributed: NotificationCenter = DistributedNotificationCenter.default(),
         initialState: @escaping () -> State = {
             let session = CGSessionCopyCurrentDictionary() as? [String: Any]
             return State(locked: session?["CGSSessionScreenIsLocked"] as? Bool ?? false,
                          onConsole: SessionActivitySupport.isOnConsole(session))
         }, play: @escaping (Bool) -> Void = PadlockSound.play) {
        self.defaults = defaults; self.workspace = workspace; self.distributed = distributed
        self.initialState = initialState; self.play = play
        preferenceObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main) { [weak self] _ in
                self?.syncWithPreferences()
            }
    }

    deinit {
        stop()
        if let preferenceObserver { NotificationCenter.default.removeObserver(preferenceObserver) }
    }

    func syncWithPreferences() {
        guard defaults.bool(forKey: DefaultsKey.notchLockSounds) else { stop(); return }
        guard observers.isEmpty else { return }
        state = initialState() // Enabling while locked never replays an old transition.
        observe(distributed, "com.apple.screenIsLocked") { $0.locked = true }
        observe(distributed, "com.apple.screenIsUnlocked") { $0.locked = false; $0.screenSaverRunning = false }
        observe(distributed, "com.apple.screensaver.didstart") { $0.screenSaverRunning = true }
        observe(distributed, "com.apple.screensaver.didstop") { $0.screenSaverRunning = false }
        observe(workspace, NSWorkspace.willSleepNotification.rawValue) { $0.sleeping = true }
        observe(workspace, NSWorkspace.didWakeNotification.rawValue) { $0.sleeping = false; $0.screenSaverRunning = false }
        observe(workspace, NSWorkspace.screensDidSleepNotification.rawValue) { $0.displaysSleeping = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue) { $0.displaysSleeping = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification.rawValue) { $0.onConsole = false }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification.rawValue) { $0.onConsole = true }
    }

    private func stop() {
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: String, change: @escaping (inout State) -> Void) {
        let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            guard let self, self.defaults.bool(forKey: DefaultsKey.notchLockSounds) else { return }
            let wasLocked = self.state.locked
            change(&self.state)
            guard wasLocked != self.state.locked, self.state.onConsole else { return }
            if self.state.locked && (self.state.sleeping || self.state.displaysSleeping || self.state.screenSaverRunning) { return }
            self.play(self.state.locked)
        }
        observers.append((center, token))
    }
}
