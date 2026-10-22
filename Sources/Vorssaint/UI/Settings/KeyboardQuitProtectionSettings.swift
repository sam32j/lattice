import SwiftUI

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
                Toggle(quitStrings.enabled, isOn: enabled)
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
                    SettingsSliderRow(title: quitStrings.holdDuration, value: holdDuration,
                                      range: QuitProtectionSupport.holdDurationRange, step: 50,
                                      readout: "\(Int(holdDuration.wrappedValue.rounded())) ms")
                        .onChange(of: holdDuration.wrappedValue) { _, _ in quitService.syncWithPreferences() }
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

                SettingsToggleRow(title: quitStrings.feedback, isOn: showFeedback)
                    .onChange(of: showFeedback.wrappedValue) { _, _ in quitService.syncWithPreferences() }
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
            VStack(alignment: .leading, spacing: 7) {
                Text(quitStrings.exceptions).font(.subheadline.weight(.semibold))
                let values = quitService.exceptions(for: shortcut)
                if values.isEmpty {
                    Text(quitStrings.noExceptions).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(values, id: \.self) { bundleID in
                        HStack(spacing: 8) {
                            Image(nsImage: InstalledApps.icon(for: bundleID))
                                .resizable().frame(width: 20, height: 20)
                            Text(InstalledApps.name(for: bundleID))
                            Spacer()
                            Button {
                                quitService.removeException(bundleID, for: shortcut)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button { pickerShortcut = shortcut } label: {
                    Label(quitStrings.addApp, systemImage: "plus")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(!enabled)
            }
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
