// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum CompactShortcutValidationTests {
    enum SystemShortcutTakeover {
        static var conflict = false, takenOver = false
        static var changes: [Bool] = []
        static func conflictsWithMacOS(_ shortcut: GlobalShortcut, for role: GlobalShortcutRole) -> Bool { conflict }
        static func isTakenOver(_ key: String) -> Bool { takenOver }
        static func setTakeOver(_ key: String, _ value: Bool) { takenOver = value; changes.append(value) }
    }
    class State {
        struct Localization { let s = Strings.enUS }
        let l10n = Localization()
        var role = GlobalShortcutRole.screenshot
        var rawValue = GlobalShortcut.screenshotDefault.storageValue
        var isEnabled = false, systemConflict = false
        var errorText: String?
        var pendingTakeOver: GlobalShortcut?
        var conflictingRole: GlobalShortcutRole?
        var includeInactiveConflicts = false
        var notifications = 0
        func additionalConflict(_ shortcut: GlobalShortcut) -> String? { nil }
        func showError(_ text: String) { errorText = text }
        func onChange() { notifications += 1 }
    }
    static func run(_ suite: TestSuite) {
        let clearedKey = "test.shortcut.cleared.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: clearedKey) }
        suite.expect(GlobalShortcut.saved(for: clearedKey, fallback: .screenshotDefault) == .screenshotDefault,
                     "an unset shortcut retains its default for existing installations")
        UserDefaults.standard.set("", forKey: clearedKey)
        suite.expect(!GlobalShortcut.saved(for: clearedKey, fallback: .screenshotDefault).isValid,
                     "an explicitly cleared shortcut stays disabled rather than restoring its default")
        UserDefaults.standard.set(GlobalShortcut.screenshotDefault.storageValue, forKey: clearedKey)
        suite.expect(GlobalShortcut.saved(for: clearedKey, fallback: .keepAwakeDefault) == .screenshotDefault,
                     "recording after clear restores the selected shortcut")
        defer { SystemShortcutTakeover.conflict = false; SystemShortcutTakeover.takenOver = false
            SystemShortcutTakeover.changes = [] }
        let recorder = Recorder()
        recorder.isEnabled = true
        recorder.clearShortcut()
        suite.expect(!recorder.isEnabled && recorder.rawValue.isEmpty && recorder.notifications == 1,
                     "clear disables a dedicated shortcut and removes its assignment")
        recorder.role = .displayBrightnessDecrease
        recorder.isEnabled = true
        recorder.clearShortcut()
        suite.expect(recorder.isEnabled && recorder.rawValue.isEmpty,
                     "clearing one brightness shortcut preserves the shared enable flag for its sibling")
        recorder.role = .screenshot
        recorder.isEnabled = false
        recorder.rawValue = recorder.role.defaultShortcut.storageValue
        recorder.notifications = 0
        recorder.errorText = nil
        SystemShortcutTakeover.changes = []
        let shortcut = recorder.role.defaultShortcut
        recorder.conflictingRole = .clipboard
        recorder.resetToDefault()
        suite.expect(!recorder.isEnabled && recorder.notifications == 0 && recorder.errorText != nil,
                     "reset refuses an internal conflict without enabling or changing another feature")
        recorder.conflictingRole = nil
        SystemShortcutTakeover.conflict = true
        suite.expect(recorder.validationDecision(shortcut) == nil,
                     "compact recording rejects an unapproved macOS conflict")
        SystemShortcutTakeover.takenOver = true
        recorder.resetToDefault()
        suite.expect(recorder.isEnabled && SystemShortcutTakeover.takenOver
                     && SystemShortcutTakeover.changes.isEmpty,
                     "reset preserves approval for the unchanged default shortcut already taken over")
        let other = GlobalShortcut(keyCode: 0, modifiers: [.control, .option])
        suite.expect(recorder.validationDecision(other) == nil,
                     "existing takeover does not authorize a different conflicting combination")
        SystemShortcutTakeover.conflict = false
        suite.expect(recorder.validationDecision(other) == .save(clearTakeOver: true),
                     "saving a free combination clears stale takeover state")
        recorder.role = .switcher
        recorder.rawValue = recorder.role.defaultShortcut.storageValue
        recorder.systemConflict = true
        suite.expect(recorder.validationDecision(recorder.role.defaultShortcut) == nil,
                     "roles without takeover support reject macOS conflicts even with a stale approval")
    }
}
