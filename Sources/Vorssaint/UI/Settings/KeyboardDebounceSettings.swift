import SwiftUI

extension KeyboardSettings {
    // MARK: - Keyboard Debounce Card

    var keyboardDebounceCard: some View {
        SettingsCard(title: l10n.s.keyDebounceName) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(symbol: "keyboard", title: l10n.s.keyDebounceEnable,
                            caption: l10n.s.keyDebounceCaption) {
                    PermissionGatedToggle(l10n.s.keyDebounceEnable, isOn: $debounceEnabled)
                        .labelsHidden()
                        .onChange(of: debounceEnabled) { _, value in
                            debounce.syncWithPreferences()
                            features.finishAvailabilityChange()
                            guard value, !permissions.accessibility else { return }
                            permissions.requestAccessibility()
                            permissions.openAccessibilitySettings()
                        }
                }

                if debounceEnabled {
                SettingsSliderRow(title: l10n.s.keyDebounceGlobalWindow,
                                  value: Binding(get: { Double(globalWindowBinding.wrappedValue) },
                                                 set: { globalWindowBinding.wrappedValue = Int($0.rounded()) }),
                                  range: Double(Defaults.allowedKeyboardDebounceWindowRange.lowerBound)...Double(Defaults.allowedKeyboardDebounceWindowRange.upperBound),
                                  step: Double(Defaults.keyboardDebounceWindowStep), readout: "\(globalWindow) ms")
                    .padding(.leading, settingsRowTextInset)
                    .disabled(!debounceEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.s.keyDebouncePerKeySection).font(.subheadline.weight(.semibold))
                        .help(l10n.s.keyDebouncePerKeyCaption)

                    if !keyWindows.isEmpty {
                        ForEach(keyWindows) { row in
                            HStack(spacing: 8) {
                                Text(KeyboardDebounceKeyCatalog.label(for: row.keyCode))
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .frame(minWidth: 28, minHeight: 28)
                                    .padding(.horizontal, 6)
                                    .background(.background, in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                                Spacer(minLength: 12)
                                Stepper(value: debounceBinding(for: row.keyCode),
                                        in: Defaults.allowedKeyboardDebounceWindowRange,
                                        step: Defaults.keyboardDebounceWindowStep) {
                                    Text("\(row.window) ms").foregroundStyle(.secondary).monospacedDigit()
                                }
                                .fixedSize()
                                Button(l10n.s.keyDebounceRemoveKey) {
                                    removeWindow(for: row.keyCode)
                                }
                                .help(l10n.s.keyDebounceRemoveKey)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Picker(l10n.s.keyDebounceKeyLabel, selection: $selectedKeyCode) {
                            Text(l10n.s.keyDebounceKeyLabel).tag(Int64?.none)
                            ForEach(KeyboardDebounceKeyCatalog.available(excluding: Set(keyWindows.map(\.keyCode)))) { key in
                                Text(key.label).tag(Optional(key.code))
                            }
                        }
                        .labelsHidden().pickerStyle(.menu)
                        .fixedSize()
                        .frame(width: 160, alignment: .leading)

                        Spacer(minLength: 12)
                        Stepper(value: $selectedWindow,
                                in: Defaults.allowedKeyboardDebounceWindowRange,
                                step: Defaults.keyboardDebounceWindowStep) {
                            Text("\(selectedWindow) ms").monospacedDigit()
                        }
                        .fixedSize()

                        Button(l10n.s.keyDebounceAddKey) {
                            if let selectedKeyCode {
                                setWindow(selectedWindow, for: selectedKeyCode)
                                self.selectedKeyCode = nil
                            }
                        }
                        .disabled(!debounceEnabled || selectedKeyCode == nil)
                    }
                }
                .padding(.leading, settingsRowTextInset)
                .disabled(!debounceEnabled)
                }
            }
        }
    }

    var globalWindowBinding: Binding<Int> {
        Binding {
            Defaults.sanitizedKeyboardDebounceWindow(globalWindow)
        } set: { value in
            globalWindow = Defaults.sanitizedKeyboardDebounceWindow(value)
            debounce.syncWithPreferences()
        }
    }

    var keyWindows: [KeyWindowRow] {
        KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
            .map { KeyWindowRow(keyCode: $0.key, window: $0.value) }
            .sorted {
                KeyboardDebounceKeyCatalog.label(for: $0.keyCode) < KeyboardDebounceKeyCatalog.label(for: $1.keyCode)
            }
    }

    func debounceBinding(for keyCode: Int64) -> Binding<Int> {
        Binding {
            KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)[keyCode]
                ?? Defaults.defaultKeyboardDebounceWindowMs
        } set: { value in
            setWindow(value, for: keyCode)
        }
    }

    func setWindow(_ value: Int, for keyCode: Int64) {
        var windows = KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
        windows[keyCode] = Defaults.sanitizedKeyboardDebounceWindow(value)
        keyWindowsRaw = KeyboardDebounceConfig.encodeKeyWindows(windows)
        debounce.syncWithPreferences()
    }

    func removeWindow(for keyCode: Int64) {
        var windows = KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
        windows.removeValue(forKey: keyCode)
        keyWindowsRaw = KeyboardDebounceConfig.encodeKeyWindows(windows)
        debounce.syncWithPreferences()
    }

}
