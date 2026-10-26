import Foundation

enum WindowLayoutShortcutEditorTests {
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.layout-editor.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let shortcut = GlobalShortcut(keyCode: 18, modifiers: [.control, .option, .command])
        defaults.set(false, forKey: DefaultsKey.windowLayoutShortcutsEnabled)
        defaults.set(shortcut.storageValue, forKey: WindowLayoutAction.rightHalf.shortcutKey)
        let result = WindowLayoutShortcutEditor.save(shortcut, for: .leftHalf, in: defaults,
            language: .enUS, conflictsWithSystem: false, takenOver: false)
        if case .conflict = result { suite.expect(true, "duplicate rejected") }
        else { suite.expect(false, "saving while paused must check bindings that would become active") }
        suite.expect(!defaults.bool(forKey: DefaultsKey.windowLayoutShortcutsEnabled),
                     "a rejected assignment never activates paused shortcuts")
        defaults.set(WindowLayoutAction.clearedShortcutStorageValue, forKey: WindowLayoutAction.rightHalf.shortcutKey)
        let saved = WindowLayoutShortcutEditor.save(shortcut, for: .leftHalf, in: defaults,
            language: .enUS, conflictsWithSystem: false, takenOver: false)
        if case .saved = saved { suite.expect(true, "valid assignment saves") }
        else { suite.expect(false, "a free assignment is saved") }
        suite.expect(!defaults.bool(forKey: DefaultsKey.windowLayoutShortcutsEnabled)
                     && defaults.string(forKey: WindowLayoutAction.leftHalf.shortcutKey) == shortcut.storageValue,
                     "editing a paused group preserves its inactive state and the new binding")
        _ = WindowLayoutShortcutEditor.clear(.leftHalf, in: defaults)
        suite.expect(defaults.string(forKey: WindowLayoutAction.leftHalf.shortcutKey)
                     == WindowLayoutAction.clearedShortcutStorageValue,
                     "clear writes the explicit empty binding rather than restoring a default")
        defaults.set(true, forKey: AppFeature.quickLauncher.availabilityKey)
        defaults.set(shortcut.storageValue, forKey: GlobalShortcutRole.quickLauncher.storageKey)
        for key in GlobalShortcutRole.quickLauncher.requiredEnableKeys { defaults.set(false, forKey: key) }
        let inactiveRoleResult = WindowLayoutShortcutEditor.save(shortcut, for: .leftHalf, in: defaults,
            language: .enUS, conflictsWithSystem: false, takenOver: false)
        if case .saved = inactiveRoleResult { suite.expect(true, "inactive role does not conflict") }
        else { suite.expect(false, "disabled features do not reserve shortcuts") }
        for key in GlobalShortcutRole.quickLauncher.requiredEnableKeys { defaults.set(true, forKey: key) }
        let roleConflict = WindowLayoutShortcutEditor.save(shortcut, for: .leftHalf, in: defaults,
            language: .enUS, conflictsWithSystem: false, takenOver: false)
        if case .conflict = roleConflict { suite.expect(true, "active role conflict rejected") }
        else { suite.expect(false, "both editors reject an active role's binding from the same preference store") }
        defaults.set(WindowLayoutAction.clearedShortcutStorageValue, forKey: WindowLayoutAction.leftHalf.shortcutKey)
        defaults.set("", forKey: GlobalShortcutRole.quickLauncher.storageKey)
        let offer = WindowLayoutShortcutEditor.save(shortcut, for: .leftHalf, in: defaults,
            language: .enUS, conflictsWithSystem: true, takenOver: false)
        if case .offer = offer { suite.expect(true, "system conflict asks for takeover") }
        else { suite.expect(false, "cleared roles do not reserve a binding but macOS conflicts require approval") }
        suite.expect(defaults.string(forKey: WindowLayoutAction.leftHalf.shortcutKey)
                     == WindowLayoutAction.clearedShortcutStorageValue,
                     "a takeover offer does not persist before approval")
        defaults.set(shortcut.storageValue, forKey: WindowLayoutAction.rightHalf.shortcutKey)
        let staleOffer = WindowLayoutShortcutEditor.save(shortcut, for: .leftHalf, in: defaults,
            language: .enUS, conflictsWithSystem: true, takenOver: false, approveSystemConflict: true)
        if case .conflict = staleOffer { suite.expect(true, "takeover revalidates") }
        else { suite.expect(false, "takeover acceptance rejects a binding assigned elsewhere while the offer was open") }
        defaults.set(WindowLayoutAction.clearedShortcutStorageValue, forKey: WindowLayoutAction.rightHalf.shortcutKey)
        let accepted = WindowLayoutShortcutEditor.save(shortcut, for: .leftHalf, in: defaults,
            language: .enUS, conflictsWithSystem: true, takenOver: false, approveSystemConflict: true)
        if case .saved(_, takeOver: true) = accepted { suite.expect(true, "approved takeover persists") }
        else { suite.expect(false, "explicit takeover approval saves with matching ownership") }
    }
}
