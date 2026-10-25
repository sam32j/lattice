// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Keyboard page: consolidates Quit & Close Protection, Keyboard Debounce, and Super Key.
struct KeyboardSettings: View {
    struct KeyWindowRow: Identifiable {
        let keyCode: Int64
        let window: Int
        var id: Int64 { keyCode }
    }

    struct ModifierChoice: Identifiable {
        let modifier: GlobalShortcutModifiers
        let symbol: String
        let name: String
        var id: String { name }
    }

    @ObservedObject var l10n = L10n.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var quitService = QuitProtectionService.shared
    @ObservedObject var debounce = KeyboardDebounceService.shared
    @ObservedObject var superKey = SuperKeyService.shared

    // MARK: - Quit & Close Protection State
    @AppStorage(DefaultsKey.quitProtectionQuitEnabled) var quitEnabled = false
    @AppStorage(DefaultsKey.quitProtectionQuitMode) var quitMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitHoldDurationMs) var quitHoldDuration = QuitProtectionSupport.defaultHoldDurationMilliseconds
    @AppStorage(DefaultsKey.quitProtectionQuitDoubleIntervalMs) var quitDoubleInterval = QuitProtectionSupport.defaultDoublePressIntervalMilliseconds
    @AppStorage(DefaultsKey.quitProtectionQuitExtraModifier) var quitExtraModifier = QuitProtectionExtraModifier.shift.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitScope) var quitScope = QuitProtectionScope.all.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitShowFeedback) var quitShowFeedback = true

    @AppStorage(DefaultsKey.quitProtectionCloseEnabled) var closeEnabled = false
    @AppStorage(DefaultsKey.quitProtectionCloseMode) var closeMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseHoldDurationMs) var closeHoldDuration = QuitProtectionSupport.defaultHoldDurationMilliseconds
    @AppStorage(DefaultsKey.quitProtectionCloseDoubleIntervalMs) var closeDoubleInterval = QuitProtectionSupport.defaultDoublePressIntervalMilliseconds
    @AppStorage(DefaultsKey.quitProtectionCloseExtraModifier) var closeExtraModifier = QuitProtectionExtraModifier.shift.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseScope) var closeScope = QuitProtectionScope.all.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseShowFeedback) var closeShowFeedback = true


    // MARK: - Keyboard Debounce State
    @AppStorage(DefaultsKey.keyboardDebounceEnabled) var debounceEnabled = false
    @AppStorage(DefaultsKey.keyboardDebounceWindowMs) var globalWindow = Defaults.defaultKeyboardDebounceWindowMs
    @AppStorage(DefaultsKey.keyboardDebounceKeyWindows) var keyWindowsRaw = ""
    @State var selectedKeyCode: Int64?
    @State var selectedWindow = Defaults.defaultKeyboardDebounceWindowMs

    // MARK: - Super Key State
    @AppStorage(DefaultsKey.superKeyEnabled) var superKeyEnabled = false
    @AppStorage(DefaultsKey.superKeySource) var sourceRaw = SuperKeySource.capsLock.rawValue
    @AppStorage(DefaultsKey.superKeyModifiers) var modifierStorage = SuperKeySupport.defaultModifierStorageValue
    @AppStorage(DefaultsKey.superKeySoloAction) var soloActionRaw = SuperKeySoloAction.none.rawValue

    let modifierChoices = [
        ModifierChoice(modifier: .shift, symbol: "⇧", name: "Shift"),
        ModifierChoice(modifier: .control, symbol: "⌃", name: "Control"),
        ModifierChoice(modifier: .option, symbol: "⌥", name: "Option"),
        ModifierChoice(modifier: .command, symbol: "⌘", name: "Command"),
    ]

    var quitStrings: QuitProtectionStrings { FeatureStrings.quitProtection(l10n.language) }
    var text: SuperKeyStrings { FeatureStrings.superKey(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                superKeyCard
                    .settingsSectionAnchor(.superKey, cornerRadius: 16)
                quitProtectionCard
                    .settingsSectionAnchor(.quitProtection, cornerRadius: 16)

                keyboardDebounceCard
                    .settingsSectionAnchor(.keyboardDebounce, cornerRadius: 16)

                if BrightnessService.keyboardLightIsSupported {
                    KeyboardLightSettings()
                        .settingsSectionAnchor(.keyboardBrightnessShortcuts, cornerRadius: 16)
                }

                CleaningModeSettings()
                    .settingsSectionAnchor(.cleaningMode, cornerRadius: 16)

                if (quitEnabled || closeEnabled || debounceEnabled || superKeyEnabled || AppFeature.cleaningMode.isAvailable) && !permissions.accessibility {
                    SettingsCard(title: l10n.s.permissionRequired) {
                        PermissionRow(kind: .accessibility)
                    }
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .onAppear {
            quitService.syncWithPreferences()
            debounce.syncWithPreferences()
            superKey.syncWithPreferences()
            CleaningModeManager.shared.syncWithPreferences()
            globalWindow = Defaults.sanitizedKeyboardDebounceWindow(globalWindow)
            selectedWindow = Defaults.sanitizedKeyboardDebounceWindow(selectedWindow)
        }
    }

}
