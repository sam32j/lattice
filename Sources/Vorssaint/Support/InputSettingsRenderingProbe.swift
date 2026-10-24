#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Render expanded input controls without mounting the page lifecycle hooks,
/// installing input taps, remapping a real key, or changing display hardware.
enum InputSettingsRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        let enabledKeys = [DefaultsKey.scrollInverterEnabled, DefaultsKey.scrollInverterHorizontalEnabled,
                           DefaultsKey.scrollHorizontalEnabled, DefaultsKey.smoothScrollEnabled,
                           DefaultsKey.linearScrollEnabled, DefaultsKey.mouseAccelerationDisabled,
                           DefaultsKey.focusFollowsMouseEnabled, DefaultsKey.mouseClickDebounceEnabled,
                           DefaultsKey.mouseNavigationEnabled, DefaultsKey.mouseButtonShortcutsEnabled,
                           DefaultsKey.mouseSpacesGestureEnabled, DefaultsKey.middleClickEnabled,
                           DefaultsKey.superKeyEnabled, DefaultsKey.keyboardDebounceEnabled,
                           DefaultsKey.quitProtectionQuitEnabled, DefaultsKey.quitProtectionCloseEnabled]
        for key in enabledKeys { UserDefaults.standard.set(true, forKey: key) }
        // Exercise actual registered-key rows, not just the empty editor.
        UserDefaults.standard.set(KeyboardDebounceConfig.encodeKeyWindows([0: 25, 12: 50]),
                                  forKey: DefaultsKey.keyboardDebounceKeyWindows)
        let pages: [(String, AnyView, CGFloat)] = [
            ("mouse-scrolling-enabled", AnyView(MouseSettings().mouseScrollingCard), 1000),
            ("mouse-clicks-enabled", AnyView(MouseSettings().mouseClicksCard), 550),
            ("mouse-buttons-enabled", AnyView(MouseSettings().mouseButtonsCard), 820),
            ("trackpad-enabled", AnyView(MouseSettings().middleClickCard), 440),
            ("keyboard-super-key-enabled", AnyView(KeyboardSettings().superKeyCard), 470),
            ("keyboard-quit-enabled", AnyView(KeyboardSettings().quitProtectionCard), 700),
            ("keyboard-filter-enabled", AnyView(KeyboardSettings().keyboardDebounceCard), 600),
        ]
        for (name, view, height) in pages {
            SettingsRefactorProbe.render(name, view: AnyView(view.padding(22).toggleStyle(.switch)),
                                        size: CGSize(width: 760, height: height), output: output, failures: &failures)
        }
        let filterStates: [(String, Bool, AppLanguage, [Int64: Int])] = [
            ("keyboard-filter-empty", true, .enUS, [:]),
            ("keyboard-filter-disabled-populated", false, .enUS, [0: 25, 12: 50]),
            ("keyboard-filter-german-long-key", true, .de, [117: 25, 49: 50]),
        ]
        for (name, enabled, language, overrides) in filterStates {
            UserDefaults.standard.set(enabled, forKey: DefaultsKey.keyboardDebounceEnabled)
            UserDefaults.standard.set(KeyboardDebounceConfig.encodeKeyWindows(overrides),
                                      forKey: DefaultsKey.keyboardDebounceKeyWindows)
            L10n.shared.language = language
            SettingsRefactorProbe.render(name,
                view: AnyView(KeyboardSettings().keyboardDebounceCard.padding(22).toggleStyle(.switch)),
                size: CGSize(width: 760, height: 600), output: output, failures: &failures)
        }
        L10n.shared.language = .enUS
        UserDefaults.standard.set(QuitProtectionScope.selectedOnly.rawValue, forKey: DefaultsKey.quitProtectionQuitScope)
        UserDefaults.standard.set(QuitProtectionScope.allExceptSelected.rawValue, forKey: DefaultsKey.quitProtectionCloseScope)
        SettingsRefactorProbe.render("keyboard-quit-als-scopes",
            view: AnyView(KeyboardSettings().quitProtectionCard.padding(22).toggleStyle(.switch)),
            size: CGSize(width: 760, height: 950), output: output, failures: &failures)
        for (name, enabledOnly, shortcut) in [("quit-allowlist-sheet", true, "⌘Q"), ("close-blocklist-sheet", false, "⌘W")] {
            let copy = QuitProtectionAppListStrings.text(enabledOnly: enabledOnly, shortcut: shortcut, language: .enUS)
            let sheet = AppListSheet(caption: copy.caption, title: copy.title, onDone: {}) {
                Text("Example App").frame(maxWidth: .infinity, alignment: .leading).padding()
            } footer: { Button("Add an app…") {} }
            SettingsRefactorProbe.render(name, view: AnyView(sheet), size: CGSize(width: 520, height: 460),
                                        output: output, failures: &failures)
        }
        let filteredDevices = PriorityDeviceList(priorityUIDs: ["unknown", "airpods", "speakers"],
            isAvailable: { $0 == "speakers" },
            displayName: { ["airpods": "AirPods Pro", "speakers": "MacBook Air Speakers"][$0] },
            currentUID: "speakers", emptyText: "No devices", onMove: { _ in })
        SettingsRefactorProbe.render("audio-priority-filtered", view: AnyView(filteredDevices.padding(22)),
            size: CGSize(width: 760, height: 240), output: output, failures: &failures)
        let statuses = SettingsCard(title: "Status dot states") {
            HStack { Text("Super Key"); SettingsStatusDot(status: SettingsFeatureStatus(
                color: .green, message: InputSettingsStrings.text(.superKeyActive, .enUS))) }
            HStack { Text("Super Key"); SettingsStatusDot(status: SettingsFeatureStatus(
                color: .red, message: InputSettingsStrings.text(.superKeyConflict, .enUS))) }
            HStack { Text("Super Key"); SettingsStatusDot(status: SettingsFeatureStatus(
                color: .secondary, message: InputSettingsStrings.text(.off, .enUS))) }
        }
        SettingsRefactorProbe.render("input-status-dots", view: AnyView(statuses.padding(22)),
                                    size: CGSize(width: 760, height: 220), output: output, failures: &failures)
        for language in AppLanguage.allCases {
            for key in InputSettingsStrings.Key.allCases where InputSettingsStrings.text(key, language).isEmpty {
                failures.append("missing input settings label \(language.rawValue): \(key)")
            }
        }
    }
}
#endif
