#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Render expanded input controls without mounting the page lifecycle hooks,
/// installing input taps, remapping a real key, or changing display hardware.
enum InputSettingsRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        SettingsRefactorProbe.render("audio-input-compact-panel",
            view: AnyView(AudioInputDeviceControls().padding(12)),
            size: CGSize(width: 340, height: 260), output: output, failures: &failures)
        SettingsRefactorProbe.render("audio-input-wide-settings",
            view: AnyView(AudioInputDeviceControls(title: "Input", sliderWidth: 220,
                                                  showsUnavailableLabel: true).padding(12)),
            size: CGSize(width: 760, height: 260), output: output, failures: &failures)
        let enabledKeys = [DefaultsKey.scrollInverterEnabled, DefaultsKey.scrollInverterHorizontalEnabled,
                           DefaultsKey.scrollHorizontalEnabled, DefaultsKey.smoothScrollEnabled,
                           DefaultsKey.linearScrollEnabled, DefaultsKey.mouseAccelerationDisabled,
                           DefaultsKey.focusFollowsMouseEnabled, DefaultsKey.mouseClickDebounceEnabled,
                           DefaultsKey.mouseNavigationEnabled, DefaultsKey.mouseButtonShortcutsEnabled,
                           DefaultsKey.mouseSpacesGestureEnabled, DefaultsKey.middleClickEnabled,
                           DefaultsKey.superKeyEnabled, DefaultsKey.keyboardDebounceEnabled,
                           DefaultsKey.quitProtectionQuitEnabled, DefaultsKey.quitProtectionCloseEnabled]
        for key in enabledKeys { UserDefaults.standard.set(true, forKey: key) }
        let pages: [(String, AnyView, CGFloat)] = [
            ("mouse-scrolling-enabled", AnyView(MouseSettings().mouseScrollingCard), 1000),
            ("mouse-clicks-enabled", AnyView(MouseSettings().mouseClicksCard), 550),
            ("mouse-buttons-enabled", AnyView(MouseSettings().mouseButtonsCard), 820),
            ("trackpad-enabled", AnyView(MouseSettings().middleClickCard), 440),
            ("keyboard-super-key-enabled", AnyView(KeyboardSettings().superKeyCard), 470),
            ("keyboard-quit-enabled", AnyView(KeyboardSettings().quitProtectionCard), 700),
            ("keyboard-filter-enabled", AnyView(KeyboardSettings().keyboardDebounceCard), 440),
        ]
        for (name, view, height) in pages {
            SettingsRefactorProbe.render(name, view: AnyView(view.padding(22).toggleStyle(.switch)),
                                        size: CGSize(width: 760, height: height), output: output, failures: &failures)
        }
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
