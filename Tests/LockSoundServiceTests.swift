// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AppKit

enum LockSoundServiceTests {
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.lock-sounds.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let workspace = NotificationCenter(), distributed = NotificationCenter()
        var sounds: [Bool] = []
        let service = LockSoundService(defaults: defaults, workspace: workspace, distributed: distributed,
            initialState: { .init() }, play: { sounds.append($0) })
        func post(_ name: String) { distributed.post(name: Notification.Name(name), object: nil) }
        service.syncWithPreferences()
        post("com.apple.screenIsLocked")
        suite.expect(sounds.isEmpty, "disabled sounds install no lock listeners")
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchLockSounds)
        service.syncWithPreferences()
        service.syncWithPreferences()
        post("com.apple.screenIsLocked")
        post("com.apple.screenIsLocked")
        post("com.apple.screenIsUnlocked")
        suite.expect(sounds == [true, false], "sounds work with the island off, once per actual transition")
        workspace.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        post("com.apple.screenIsLocked")
        suite.expect(sounds == [true, false], "locking with a sleeping display is silent")
        workspace.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        post("com.apple.screenIsUnlocked")
        suite.expect(sounds == [true, false, false], "unlocking the awake session plays its sound")
        workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        post("com.apple.screenIsLocked")
        post("com.apple.screenIsUnlocked")
        suite.expect(sounds.count == 3, "a switched-away user session stays silent")
        workspace.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        post("com.apple.screensaver.didstart")
        post("com.apple.screenIsLocked")
        suite.expect(sounds.count == 3, "an idle screensaver lock stays silent")
        post("com.apple.screenIsUnlocked")
        defaults.set(false, forKey: DefaultsKey.notchLockSounds)
        service.syncWithPreferences()
        let before = sounds
        post("com.apple.screenIsLocked")
        suite.expect(sounds == before, "turning sounds off removes the session listeners immediately")
        defaults.set(true, forKey: DefaultsKey.notchLockSounds)
        var enabledWhileLocked: [Bool] = []
        let locked = LockSoundService(defaults: defaults, workspace: NotificationCenter(), distributed: distributed,
            initialState: { .init(locked: true) }, play: { enabledWhileLocked.append($0) })
        locked.syncWithPreferences()
        suite.expect(enabledWhileLocked.isEmpty, "enabling while locked never replays an old event")
        post("com.apple.screenIsUnlocked")
        suite.expect(enabledWhileLocked == [false], "a service started locked still hears the next unlock")
        let lock = PadlockSound.url(locking: true), unlock = PadlockSound.url(locking: false)
        suite.expect(lock != nil && unlock != nil && lock != unlock, "lock and unlock resources remain available")
    }
}
