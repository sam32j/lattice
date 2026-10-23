// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum KeyboardPermissionLifecycleTests {
    enum ReviewDefaults { static var current: UserDefaults! }
    enum SessionActivity {
        static var shared = Activity()
        struct Activity { var isActive = true }
    }
    class State {
        let eventLock = NSLock()
        var accessibilityGranted = true
        var isRunning = false
        var config = KeyboardDebounceConfig(enabled: false, globalWindowMs: 5, keyWindows: [:])
        func start() { isRunning = true }
        func stop() { isRunning = false }
    }

    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.keyboard-permission.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        ReviewDefaults.current = defaults
        defer { defaults.removePersistentDomain(forName: domain); ReviewDefaults.current = nil }
        let service = Service()
        defaults.set(true, forKey: DefaultsKey.keyboardDebounceEnabled)
        service.syncWithPreferences()
        suite.expect(service.isRunning, "granted duplicate-key protection starts through its production synchronizer")
        service.accessibilityGranted = false
        service.syncWithPreferences()
        suite.expect(!service.isRunning, "revoked Accessibility stops a previously running duplicate-key filter")
        var answer: ((SettingsPermissionResult) -> Void)?
        let activation = PermissionActivationCoordinator(requirements: [.accessibility],
            verify: { _ in service.accessibilityGranted },
            requestAccess: { _, completion in answer = completion },
            applyEnabled: { enabled in
                defaults.set(enabled, forKey: DefaultsKey.keyboardDebounceEnabled)
                service.syncWithPreferences()
            })
        activation.setEnabled(true)
        answer?(.denied)
        service.accessibilityGranted = true
        service.syncWithPreferences()
        suite.expect(!defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled) && !service.isRunning,
                     "a denied activation leaves preferences and the service off after a later grant")
    }
}
