// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// Production service synchronizers with isolated preferences, local notification
/// centers, and presentation/hotkey doubles. No real panels, timers, or shortcuts.
enum PageOwnedServiceLifecycleTests {
    enum ReviewDefaults { static var current: UserDefaults! }
    struct GlobalShortcut {
        static let snippetLibraryDefault = Self(), quickLauncherDefault = Self()
        static func saved(for key: String, fallback: Self) -> Self { fallback }
    }
    final class Hotkey {
        var registered = true
        func sync(enabled: Bool, shortcut: GlobalShortcut, storageKey: String) -> Bool {
            registered = enabled
            return true
        }
        func unregister() { registered = false }
    }
    final class Panel {
        var isVisible = true
        func orderOut(_ sender: Any?) { isVisible = false }
    }
    struct TextSnippetService {
        static let shared = Self()
        func setLibraryVisible(_ visible: Bool) {}
    }
    enum NotchService {
        static let shared = Island()
        final class Island {
            var expanded = false
            var selected = NotchModule.controls
            func collapse() { expanded = false }
        }
    }
    class PresentationState {
        let hotkey = Hotkey()
        var panel: Panel? = Panel()
        var isVisible: Bool { panel?.isVisible == true }
        var shortcutRegistrationFailed = false
        var monitors = 2
        var isEditing = true
        var editingOptionsItem: Int? = 1
        var activeUtility: Int? = 1
        func removeMonitors() { monitors = 0 }
        func reloadSnippets() {}
        func refreshPanelLayout() {}
    }
    enum NSWorkspace {
        static let shared = Workspace()
        static let willSleepNotification = Notification.Name("test.sleep")
        static let screensDidSleepNotification = Notification.Name("test.display-sleep")
        final class Workspace { let notificationCenter = NotificationCenter() }
    }
    enum DistributedNotificationCenter {
        static let center = NotificationCenter()
        static func `default`() -> NotificationCenter { center }
    }
    class ClipboardState {
        let configurationLock = NSLock()
        var configurationGeneration = 0
        var timerRunning = false
        var sleepObserver: NSObjectProtocol?
        var displaySleepObserver: NSObjectProtocol?
        var screenLockObserver: NSObjectProtocol?
        static let screenLockNotification = Notification.Name("test.lock")
        func startTimer() { timerRunning = true }
        func stopTimer() { timerRunning = false }
        func clearNow(triggerPreferenceKey: String) {}
    }

    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.page-service-lifecycle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        ReviewDefaults.current = defaults
        defer { defaults.removePersistentDomain(forName: domain); ReviewDefaults.current = nil }
        defaults.set(true, forKey: DefaultsKey.snippetLibraryEnabled)
        defaults.set(true, forKey: DefaultsKey.textSnippetsEnabled)
        let snippets = Snippets()
        snippets.syncWithPreferences()
        suite.expect(snippets.hotkey.registered, "an enabled snippets owner can register its library shortcut")
        defaults.set(false, forKey: DefaultsKey.textSnippetsEnabled)
        snippets.syncWithPreferences()
        suite.expect(!snippets.hotkey.registered && !snippets.isVisible && snippets.monitors == 0,
                     "disabling Text Snippets unregisters its library shortcut and closes its presentation")
        defaults.set(true, forKey: AppFeature.quickLauncher.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.quickLauncherShortcutEnabled)
        let launcher = Launcher()
        launcher.syncWithPreferences()
        defaults.set(false, forKey: AppFeature.quickLauncher.availabilityKey)
        launcher.syncWithPreferences()
        suite.expect(!launcher.hotkey.registered && !launcher.isVisible && launcher.monitors == 0
                     && launcher.activeUtility == nil && !launcher.isEditing,
                     "disabling Launcher Grid tears down its hotkey, panel, utility and monitors")
        defaults.set(true, forKey: DefaultsKey.clipboardHistoryEnabled)
        for key in [DefaultsKey.clipboardAutoClearOnDelay, DefaultsKey.clipboardAutoClearOnSleep,
                    DefaultsKey.clipboardAutoClearOnDisplaySleep, DefaultsKey.clipboardAutoClearOnScreenLock] {
            defaults.set(true, forKey: key)
        }
        let clipboard = Clipboard()
        clipboard.syncWithPreferences()
        suite.expect(clipboard.timerRunning && clipboard.sleepObserver != nil
                     && clipboard.displaySleepObserver != nil && clipboard.screenLockObserver != nil,
                     "enabled Clipboard installs each requested auto-clear trigger independently")
        defaults.set(false, forKey: DefaultsKey.clipboardHistoryEnabled)
        clipboard.syncWithPreferences()
        suite.expect(!clipboard.timerRunning && clipboard.sleepObserver == nil
                     && clipboard.displaySleepObserver == nil && clipboard.screenLockObserver == nil,
                     "disabling Clipboard removes its delay timer and all sleep/lock observers immediately")
    }
}
