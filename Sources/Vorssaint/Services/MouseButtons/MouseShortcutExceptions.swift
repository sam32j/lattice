import AppKit

enum MouseShortcutExceptions {
    static let defaultsKey = DefaultsKey.mouseShortcutAppExceptions

    static func list(for button: Int64, in defaults: UserDefaults = .standard) -> [String] {
        let lists = defaults.dictionary(forKey: defaultsKey) as? [String: [String]] ?? [:]
        return Defaults.sanitizedBundleIdentifierList(lists[String(button)]
            ?? defaults.stringArray(forKey: MouseExceptionScope.buttonShortcuts.defaultsKey) ?? [])
    }

    static func set(_ apps: [String], for button: Int64, in defaults: UserDefaults = .standard) {
        var lists = defaults.dictionary(forKey: defaultsKey) as? [String: [String]] ?? [:]
        lists[String(button)] = Defaults.sanitizedBundleIdentifierList(apps)
        defaults.set(lists, forKey: defaultsKey)
        if defaults === UserDefaults.standard { MouseAppExceptions.shared.reload() }
    }
}
