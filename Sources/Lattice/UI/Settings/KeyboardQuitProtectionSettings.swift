import SwiftUI

enum QuitProtectionHoldPreset: Double, CaseIterable, Identifiable {
    case veryShort = 250
    case short = 600
    case `default` = 800
    case long = 1200
    case veryLong = 1500

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .veryShort: return "Very short"
        case .short: return "Short"
        case .default: return "Default"
        case .long: return "Long"
        case .veryLong: return "Very long"
        }
    }

    static func matching(_ value: Double) -> QuitProtectionHoldPreset {
        allCases.min(by: { abs($0.rawValue - value) < abs($1.rawValue - value) }) ?? .default
    }
}

extension KeyboardSettings {
    // MARK: - Quit & Close Protection Card

    var quitProtectionCard: some View {
        SettingsCard(title: quitStrings.name) {
            VStack(alignment: .leading, spacing: 14) {
                shortcutSection(shortcut: .quit, enabled: $quitEnabled, mode: $quitMode,
                                holdDuration: $quitHoldDuration, doubleInterval: $quitDoubleInterval,
                                extraModifier: $quitExtraModifier, scope: $quitScope, showFeedback: $quitShowFeedback)

                Divider()

                shortcutSection(shortcut: .close, enabled: $closeEnabled, mode: $closeMode,
                                holdDuration: $closeHoldDuration, doubleInterval: $closeDoubleInterval,
                                extraModifier: $closeExtraModifier, scope: $closeScope, showFeedback: $closeShowFeedback)
            }
        }
    }

    @ViewBuilder
    func shortcutSection(shortcut: QuitProtectionShortcut,
                                 enabled: Binding<Bool>,
                                 mode: Binding<String>,
                                 holdDuration: Binding<Double>,
                                 doubleInterval: Binding<Double>,
                                 extraModifier: Binding<String>,
                                 scope: Binding<String>,
                                 showFeedback: Binding<Bool>) -> some View {
        let currentMode = QuitProtectionSupport.modeFor(mode.wrappedValue)
        let currentScope = QuitProtectionSupport.scopeFor(scope.wrappedValue)
        let currentModifier = QuitProtectionSupport.extraModifierFor(extraModifier.wrappedValue)

        VStack(alignment: .leading, spacing: 10) {
            SettingsRow(symbol: "shield", title: shortcut.symbol, caption: quitStrings.enabledCaption) {
                PermissionGatedToggle(quitStrings.enabled, isOn: enabled)
                    .labelsHidden()
                    .onChange(of: enabled.wrappedValue) { _, value in
                        quitService.syncWithPreferences()
                        features.finishAvailabilityChange()
                        guard value, !permissions.accessibility else { return }
                        permissions.requestAccessibility()
                        permissions.openAccessibilitySettings()
                    }
            }

            if enabled.wrappedValue {
                VStack(alignment: .leading, spacing: 10) {
                SettingsToggleRow(title: quitStrings.feedback, isOn: showFeedback)
                    .onChange(of: showFeedback.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                SettingsControlRow(title: quitStrings.mode) {
                    Picker(quitStrings.mode, selection: mode) {
                        Text(quitStrings.hold).tag(QuitProtectionMode.hold.rawValue)
                        Text(quitStrings.doublePress).tag(QuitProtectionMode.doublePress.rawValue)
                        Text(quitStrings.extraModifier).tag(QuitProtectionMode.extraModifier.rawValue)
                    }
                    .labelsHidden().pickerStyle(.menu).frame(width: 220, alignment: .trailing)
                    .onChange(of: mode.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                }
                if currentMode == .hold {
                    let presetBinding = Binding<Double>(
                        get: { QuitProtectionHoldPreset.matching(holdDuration.wrappedValue).rawValue },
                        set: { newValue in
                            holdDuration.wrappedValue = newValue
                            quitService.syncWithPreferences()
                        }
                    )
                    SettingsControlRow(title: quitStrings.holdDuration) {
                        Picker(quitStrings.holdDuration, selection: presetBinding) {
                            ForEach(QuitProtectionHoldPreset.allCases) { preset in
                                Text(preset.title).tag(preset.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 220, alignment: .trailing)
                    }
                }
                if currentMode == .doublePress {
                    SettingsSliderRow(title: quitStrings.doublePressInterval, value: doubleInterval,
                                      range: QuitProtectionSupport.doublePressIntervalRange, step: 50,
                                      readout: "\(Int(doubleInterval.wrappedValue.rounded())) ms")
                        .onChange(of: doubleInterval.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                }
                if currentMode == .extraModifier {
                    SettingsControlRow(title: quitStrings.modifier,
                                       caption: "\(modifierSymbol(currentModifier))\(shortcut.symbol)") {
                        Picker(quitStrings.modifier, selection: extraModifier) {
                            Text("\(quitStrings.shiftKey) (⇧)").tag(QuitProtectionExtraModifier.shift.rawValue)
                            Text("\(quitStrings.optionKey) (⌥)").tag(QuitProtectionExtraModifier.option.rawValue)
                            Text("\(quitStrings.controlKey) (⌃)").tag(QuitProtectionExtraModifier.control.rawValue)
                        }
                        .labelsHidden().pickerStyle(.menu).frame(width: 220, alignment: .trailing)
                        .onChange(of: extraModifier.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                    }
                }
                SettingsControlRow(title: quitStrings.appScope) {
                    Picker(quitStrings.appScope, selection: scope) {
                        Text(quitStrings.allApps).tag(QuitProtectionScope.all.rawValue)
                        Text(quitStrings.selectedOnly).tag(QuitProtectionScope.selectedOnly.rawValue)
                        Text(quitStrings.allExceptSelected).tag(QuitProtectionScope.allExceptSelected.rawValue)
                    }
                    .labelsHidden().pickerStyle(.menu).frame(width: 220, alignment: .trailing)
                    .onChange(of: scope.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                }

                exceptionsSection(for: shortcut, scope: currentScope, enabled: enabled.wrappedValue)

                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    @ViewBuilder
    func exceptionsSection(for shortcut: QuitProtectionShortcut,
                                   scope: QuitProtectionScope,
                                   enabled: Bool) -> some View {
        if scope != .all {
            let copy = QuitProtectionAppListStrings.text(enabledOnly: scope == .selectedOnly,
                                                        shortcut: shortcut.symbol, language: l10n.language)
            AppBundleList(title: copy.title, caption: copy.caption,
                          addTitle: quitStrings.addApp, removeLabel: FeatureStrings.mouseExceptions(l10n.language).removeButton,
                          bundleIDs: quitService.exceptions(for: shortcut), reachesEveryApp: true,
                          usesSheet: true, sheetTitle: copy.title,
                          onAdd: { quitService.addException($0, for: shortcut) },
                          onRemove: { quitService.removeException($0, for: shortcut) })
                .disabled(!enabled)
        }
    }

    func modifierSymbol(_ modifier: QuitProtectionExtraModifier) -> String {
        switch modifier {
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }

}
