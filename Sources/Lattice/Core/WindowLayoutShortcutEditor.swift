import Foundation

/// Both shortcut surfaces share validation and persistence. System conflict
/// detection and registration stay at the native service boundary.
enum WindowLayoutShortcutEditor {
    enum Result {
        case conflict(String, assignedBehavior: String? = nil)
        case offer
        case saved(String, takeOver: Bool)
    }

    static func save(_ shortcut: GlobalShortcut, for action: WindowLayoutAction,
                     in defaults: UserDefaults = .standard, language: AppLanguage,
                     conflictsWithSystem: Bool, takenOver: Bool,
                     approveSystemConflict: Bool = false) -> Result {
        let strings = Strings.localized(language)
        guard shortcut.isValid else { return .conflict(strings.shortcutInvalid, assignedBehavior: nil) }
        if let role = GlobalShortcutRole.conflict(for: shortcut, excluding: nil,
            isOn: { defaults.bool(forKey: $0) },
            isAvailable: { $0.isPresentInControls(in: defaults) },
            shortcutForRole: { GlobalShortcut.saved(for: $0.storageKey, fallback: $0.defaultShortcut, in: defaults) },
            radialMenuShortcuts: { RadialMenuSupport.profileShortcuts(defaults: defaults) }) {
            let roleTitle = role.title(strings)
            return .conflict(String(format: strings.shortcutConflictFormat, roleTitle), assignedBehavior: roleTitle)
        }
        let directional = defaults.bool(forKey: DefaultsKey.windowDirectionalEnabled)
            ? defaults.string(forKey: DefaultsKey.windowDirectionalShortcut).flatMap(GlobalShortcut.init(storageValue:)) : nil
        if let conflict = WindowLayoutShortcutConflict.find(shortcut, directional: directional,
            excluding: action, actionShortcut: {
                WindowLayoutAction.resolvedShortcut(storedValue: defaults.string(forKey: $0.shortcutKey),
                                                    defaultShortcut: $0.defaultShortcut)
            }) {
            let title: String
            switch conflict {
            case .directional: title = WindowDirectionalStrings.localized(language).title
            case .action(let other): title = other.title(FeatureStrings.windowLayout(language))
            }
            return .conflict(String(format: strings.shortcutConflictFormat, title), assignedBehavior: title)
        }
        let current = defaults.string(forKey: action.shortcutKey).flatMap(GlobalShortcut.init(storageValue:))
        let decision = SystemShortcutTakeoverSupport.recorderDecision(shortcut: shortcut,
            conflictsWithMacOS: conflictsWithSystem, takenOver: takenOver, current: current)
        if decision == .offer && !approveSystemConflict { return .offer }
        defaults.set(shortcut.storageValue, forKey: action.shortcutKey)
        return .saved(shortcut.storageValue, takeOver: conflictsWithSystem && (takenOver || approveSystemConflict))
    }

    static func clear(_ action: WindowLayoutAction, in defaults: UserDefaults = .standard) -> Result {
        defaults.set(WindowLayoutAction.clearedShortcutStorageValue, forKey: action.shortcutKey)
        return .saved(WindowLayoutAction.clearedShortcutStorageValue, takeOver: false)
    }
}
