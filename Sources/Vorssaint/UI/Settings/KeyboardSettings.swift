// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Keyboard page: consolidates Quit & Close Protection, Keyboard Debounce, and Super Key.
struct KeyboardSettings: View {
    private struct KeyWindowRow: Identifiable {
        let keyCode: Int64
        let window: Int
        var id: Int64 { keyCode }
    }

    private struct ModifierChoice: Identifiable {
        let modifier: GlobalShortcutModifiers
        let symbol: String
        let name: String
        var id: String { name }
    }

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var quitService = QuitProtectionService.shared
    @ObservedObject private var debounce = KeyboardDebounceService.shared
    @ObservedObject private var superKey = SuperKeyService.shared

    // MARK: - Quit & Close Protection State
    @AppStorage(DefaultsKey.quitProtectionQuitEnabled) private var quitEnabled = false
    @AppStorage(DefaultsKey.quitProtectionQuitMode) private var quitMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitHoldDurationMs) private var quitHoldDuration = QuitProtectionSupport.defaultHoldDurationMilliseconds
    @AppStorage(DefaultsKey.quitProtectionQuitDoubleIntervalMs) private var quitDoubleInterval = QuitProtectionSupport.defaultDoublePressIntervalMilliseconds
    @AppStorage(DefaultsKey.quitProtectionQuitExtraModifier) private var quitExtraModifier = QuitProtectionExtraModifier.shift.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitScope) private var quitScope = QuitProtectionScope.all.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitShowFeedback) private var quitShowFeedback = true

    @AppStorage(DefaultsKey.quitProtectionCloseEnabled) private var closeEnabled = false
    @AppStorage(DefaultsKey.quitProtectionCloseMode) private var closeMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseHoldDurationMs) private var closeHoldDuration = QuitProtectionSupport.defaultHoldDurationMilliseconds
    @AppStorage(DefaultsKey.quitProtectionCloseDoubleIntervalMs) private var closeDoubleInterval = QuitProtectionSupport.defaultDoublePressIntervalMilliseconds
    @AppStorage(DefaultsKey.quitProtectionCloseExtraModifier) private var closeExtraModifier = QuitProtectionExtraModifier.shift.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseScope) private var closeScope = QuitProtectionScope.all.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseShowFeedback) private var closeShowFeedback = true

    @State private var pickerShortcut: QuitProtectionShortcut?

    // MARK: - Keyboard Debounce State
    @AppStorage(DefaultsKey.keyboardDebounceEnabled) private var debounceEnabled = false
    @AppStorage(DefaultsKey.keyboardDebounceWindowMs) private var globalWindow = Defaults.defaultKeyboardDebounceWindowMs
    @AppStorage(DefaultsKey.keyboardDebounceKeyWindows) private var keyWindowsRaw = ""
    @State private var selectedKeyCode: Int64?
    @State private var selectedWindow = Defaults.defaultKeyboardDebounceWindowMs

    // MARK: - Super Key State
    @AppStorage(DefaultsKey.superKeyEnabled) private var superKeyEnabled = false
    @AppStorage(DefaultsKey.superKeySource) private var sourceRaw = SuperKeySource.capsLock.rawValue
    @AppStorage(DefaultsKey.superKeyModifiers) private var modifierStorage = SuperKeySupport.defaultModifierStorageValue
    @AppStorage(DefaultsKey.superKeySoloAction) private var soloActionRaw = SuperKeySoloAction.none.rawValue
    @AppStorage(DefaultsKey.cleaningModeEnabled) private var cleaningModeEnabled = true
    @AppStorage(DefaultsKey.cleaningModeKeepScreenVisible) private var cleaningModeKeepScreenVisible = false

    private let modifierChoices = [
        ModifierChoice(modifier: .shift, symbol: "⇧", name: "Shift"),
        ModifierChoice(modifier: .control, symbol: "⌃", name: "Control"),
        ModifierChoice(modifier: .option, symbol: "⌥", name: "Option"),
        ModifierChoice(modifier: .command, symbol: "⌘", name: "Command"),
    ]

    private var quitStrings: QuitProtectionStrings { FeatureStrings.quitProtection(l10n.language) }
    private var text: SuperKeyStrings { FeatureStrings.superKey(l10n.language) }
    private var pageStrings: SettingsPageStrings { FeatureStrings.settingsPages(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(pageStrings.keyboardTitle).font(.title2.bold())
                    Text(pageStrings.keyboardDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                quitProtectionCard
                    .settingsSectionAnchor(.quitProtection, cornerRadius: 16)

                keyboardDebounceCard
                    .settingsSectionAnchor(.keyboardDebounce, cornerRadius: 16)

                superKeyCard
                    .settingsSectionAnchor(.superKey, cornerRadius: 16)

                cleaningModeCard
                    .settingsSectionAnchor(.cleaningMode, cornerRadius: 16)

                if (quitEnabled || closeEnabled || debounceEnabled || superKeyEnabled || cleaningModeEnabled) && !permissions.accessibility {
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
        .sheet(item: $pickerShortcut) { shortcut in
            AppPickerView(onCancel: { pickerShortcut = nil }, onSelect: { url in
                pickerShortcut = nil
                guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
                quitService.addException(bundleID, for: shortcut)
            }, loadApps: {
                let excluded = Set(quitService.exceptions(for: shortcut))
                return InstalledApps.installedBundleApplications(excluding: excluded)
            })
        }
        .onAppear {
            quitService.syncWithPreferences()
            debounce.syncWithPreferences()
            superKey.syncWithPreferences()
            CleaningModeManager.shared.syncWithPreferences()
            globalWindow = Defaults.sanitizedKeyboardDebounceWindow(globalWindow)
            selectedWindow = Defaults.sanitizedKeyboardDebounceWindow(selectedWindow)
        }
    }

    // MARK: - Quit & Close Protection Card

    private var quitProtectionCard: some View {
        SettingsCard(title: quitStrings.name) {
            VStack(alignment: .leading, spacing: 14) {
                Text(quitStrings.intro).font(.caption).foregroundStyle(.secondary)
                Label(quitStrings.accessibilityCaption, systemImage: "hand.raised.fill")
                    .font(.caption).foregroundStyle(.secondary)

                Divider()

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
    private func shortcutSection(shortcut: QuitProtectionShortcut,
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
            HStack {
                Text(shortcut.symbol).font(.headline)
                Spacer()
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

            Text(quitStrings.enabledCaption).font(.caption).foregroundStyle(.secondary)

            if enabled.wrappedValue {
                Picker(quitStrings.mode, selection: mode) {
                    Text(quitStrings.hold).tag(QuitProtectionMode.hold.rawValue)
                    Text(quitStrings.doublePress).tag(QuitProtectionMode.doublePress.rawValue)
                    Text(quitStrings.extraModifier).tag(QuitProtectionMode.extraModifier.rawValue)
                }
                .pickerStyle(.menu)
                .onChange(of: mode.wrappedValue) { _, _ in quitService.syncWithPreferences() }

                if currentMode == .hold {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(quitStrings.holdDuration)
                            Spacer()
                            Text("\(Int(holdDuration.wrappedValue.rounded())) ms").font(.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: holdDuration, in: QuitProtectionSupport.holdDurationRange, step: 50) {
                            Text(quitStrings.holdDuration)
                        } minimumValueLabel: {
                            Text("250 ms").font(.caption2)
                        } maximumValueLabel: {
                            Text("2 s").font(.caption2)
                        }
                        .onChange(of: holdDuration.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                    }
                }

                if currentMode == .doublePress {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(quitStrings.doublePressInterval)
                            Spacer()
                            Text("\(Int(doubleInterval.wrappedValue.rounded())) ms").font(.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: doubleInterval, in: QuitProtectionSupport.doublePressIntervalRange, step: 50) {
                            Text(quitStrings.doublePressInterval)
                        } minimumValueLabel: {
                            Text("200 ms").font(.caption2)
                        } maximumValueLabel: {
                            Text("1.5 s").font(.caption2)
                        }
                        .onChange(of: doubleInterval.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                    }
                }

                if currentMode == .extraModifier {
                    HStack {
                        Picker(quitStrings.modifier, selection: extraModifier) {
                            Text("\(quitStrings.shiftKey) (⇧)").tag(QuitProtectionExtraModifier.shift.rawValue)
                            Text("\(quitStrings.optionKey) (⌥)").tag(QuitProtectionExtraModifier.option.rawValue)
                            Text("\(quitStrings.controlKey) (⌃)").tag(QuitProtectionExtraModifier.control.rawValue)
                        }
                        .onChange(of: extraModifier.wrappedValue) { _, _ in quitService.syncWithPreferences() }
                        Spacer()
                        Text("\(modifierSymbol(currentModifier))\(shortcut.symbol)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Picker(quitStrings.appScope, selection: scope) {
                    Text(quitStrings.allApps).tag(QuitProtectionScope.all.rawValue)
                    Text(quitStrings.selectedOnly).tag(QuitProtectionScope.selectedOnly.rawValue)
                    Text(quitStrings.allExceptSelected).tag(QuitProtectionScope.allExceptSelected.rawValue)
                }
                .onChange(of: scope.wrappedValue) { _, _ in quitService.syncWithPreferences() }

                exceptionsSection(for: shortcut, scope: currentScope, enabled: enabled.wrappedValue)

                Toggle(quitStrings.feedback, isOn: showFeedback)
                    .onChange(of: showFeedback.wrappedValue) { _, _ in quitService.syncWithPreferences() }
            }
        }
    }

    @ViewBuilder
    private func exceptionsSection(for shortcut: QuitProtectionShortcut,
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
                .disabled(!enabled)
            }
            .disabled(!enabled)
        }
    }

    private func modifierSymbol(_ modifier: QuitProtectionExtraModifier) -> String {
        switch modifier {
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }

    // MARK: - Keyboard Debounce Card

    private var keyboardDebounceCard: some View {
        SettingsCard(title: l10n.s.keyDebounceName) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l10n.s.keyDebounceEnable)
                    Spacer()
                    Toggle(l10n.s.keyDebounceEnable, isOn: $debounceEnabled)
                        .labelsHidden()
                        .onChange(of: debounceEnabled) { _, value in
                            debounce.syncWithPreferences()
                            features.finishAvailabilityChange()
                            guard value, !permissions.accessibility else { return }
                            permissions.requestAccessibility()
                            permissions.openAccessibilitySettings()
                        }
                }

                Text(l10n.s.keyDebounceCaption).font(.caption).foregroundStyle(.secondary)

                if debounceEnabled, debounce.isRunning {
                    Label(l10n.s.keyDebounceActiveNow, systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }

                Stepper(value: globalWindowBinding,
                        in: Defaults.allowedKeyboardDebounceWindowRange,
                        step: Defaults.keyboardDebounceWindowStep) {
                    HStack {
                        Text(l10n.s.keyDebounceGlobalWindow)
                        Spacer()
                        Text("\(globalWindow) ms").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .disabled(!debounceEnabled)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.s.keyDebouncePerKeySection).font(.subheadline.weight(.semibold))
                    Text(l10n.s.keyDebouncePerKeyCaption).font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Picker(l10n.s.keyDebounceKeyLabel, selection: $selectedKeyCode) {
                            Text(l10n.s.keyDebounceKeyLabel).tag(Int64?.none)
                            ForEach(KeyboardDebounceKeyCatalog.common) { key in
                                Text(key.label).tag(Optional(key.code))
                            }
                        }
                        .frame(minWidth: 160)

                        Stepper(value: $selectedWindow,
                                in: Defaults.allowedKeyboardDebounceWindowRange,
                                step: Defaults.keyboardDebounceWindowStep) {
                            Text("\(selectedWindow) ms").monospacedDigit()
                        }

                        Button(l10n.s.keyDebounceAddKey) {
                            if let selectedKeyCode { setWindow(selectedWindow, for: selectedKeyCode) }
                        }
                        .disabled(!debounceEnabled || selectedKeyCode == nil)
                    }

                    if keyWindows.isEmpty {
                        Text(l10n.s.keyDebounceNoOverrides).font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(keyWindows) { row in
                            HStack(spacing: 8) {
                                Text(KeyboardDebounceKeyCatalog.label(for: row.keyCode))
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 70, alignment: .leading)
                                Stepper(value: debounceBinding(for: row.keyCode),
                                        in: Defaults.allowedKeyboardDebounceWindowRange,
                                        step: Defaults.keyboardDebounceWindowStep) {
                                    Text("\(row.window) ms").foregroundStyle(.secondary).monospacedDigit()
                                }
                                Button {
                                    removeWindow(for: row.keyCode)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help(l10n.s.keyDebounceRemoveKey)
                            }
                        }
                    }
                }
                .disabled(!debounceEnabled)
            }
        }
    }

    private var globalWindowBinding: Binding<Int> {
        Binding {
            Defaults.sanitizedKeyboardDebounceWindow(globalWindow)
        } set: { value in
            globalWindow = Defaults.sanitizedKeyboardDebounceWindow(value)
            debounce.syncWithPreferences()
        }
    }

    private var keyWindows: [KeyWindowRow] {
        KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
            .map { KeyWindowRow(keyCode: $0.key, window: $0.value) }
            .sorted {
                KeyboardDebounceKeyCatalog.label(for: $0.keyCode) < KeyboardDebounceKeyCatalog.label(for: $1.keyCode)
            }
    }

    private func debounceBinding(for keyCode: Int64) -> Binding<Int> {
        Binding {
            KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)[keyCode]
                ?? Defaults.defaultKeyboardDebounceWindowMs
        } set: { value in
            setWindow(value, for: keyCode)
        }
    }

    private func setWindow(_ value: Int, for keyCode: Int64) {
        var windows = KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
        windows[keyCode] = Defaults.sanitizedKeyboardDebounceWindow(value)
        keyWindowsRaw = KeyboardDebounceConfig.encodeKeyWindows(windows)
        debounce.syncWithPreferences()
    }

    private func removeWindow(for keyCode: Int64) {
        var windows = KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
        windows.removeValue(forKey: keyCode)
        keyWindowsRaw = KeyboardDebounceConfig.encodeKeyWindows(windows)
        debounce.syncWithPreferences()
    }

    // MARK: - Super Key Card

    private var superKeyCard: some View {
        SettingsCard(title: text.pageTitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(text.enableToggle)
                    Spacer()
                    Toggle(text.enableToggle, isOn: $superKeyEnabled)
                        .labelsHidden()
                        .onChange(of: superKeyEnabled) { _, value in
                            superKey.syncWithPreferences()
                            features.finishAvailabilityChange()
                            guard value, !permissions.accessibility else { return }
                            permissions.requestAccessibility()
                            permissions.openAccessibilitySettings()
                        }
                }

                Picker(text.sourceKey, selection: sourceBinding) {
                    ForEach(SuperKeySource.allCases) { source in
                        Text(text.sourceLabel(source)).tag(source)
                    }
                }

                Text(text.enableCaption).font(.caption).foregroundStyle(.secondary)
                Label(text.modifierKeysNote, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)

                diagram

                if superKeyEnabled, let failure = superKey.mappingFailure {
                    Label(text.mappingFailure(failure), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                } else if superKeyEnabled, superKey.isPausedForApplication {
                    Label(FeatureStrings.mouseExceptions(l10n.language).pausedSuperKey, systemImage: "pause.circle")
                        .font(.caption).foregroundStyle(.secondary)
                } else if superKeyEnabled, superKey.isRunning {
                    Label(text.activeNow, systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(text.soloSection).font(.subheadline.weight(.semibold))

                    Picker(text.soloSection, selection: soloBinding) {
                        Text(text.soloNothing).tag(SuperKeySoloAction.none)
                        Text(text.soloCapsLock).tag(SuperKeySoloAction.capsLock)
                        Text(text.soloInputSource).tag(SuperKeySoloAction.inputSource)
                        Text(text.soloEscape).tag(SuperKeySoloAction.escape)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)

                    Text(text.soloCaption).font(.caption).foregroundStyle(.secondary)
                }
                .disabled(!superKeyEnabled)

                if superKeyEnabled {
                    Divider()
                    MouseExceptionsList(scope: .superKey)
                }
            }
        }
    }

    private var diagram: some View {
        HStack(spacing: 10) {
            VStack(spacing: 3) {
                keyCap(text.sourceLabel(source), symbol: source == .capsLock ? "capslock" : nil, wide: true)
                Text(text.holdHint).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                .padding(.bottom, 14)
            HStack(spacing: 5) {
                ForEach(modifierChoices) { modifierKeyCap($0) }
            }
            .padding(.bottom, 14)
        }
        .opacity(superKeyEnabled ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.18), value: superKeyEnabled)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    private func keyCap(_ title: String, symbol: String?, wide: Bool) -> some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .frame(minWidth: wide ? 84 : 30, minHeight: 30)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
    }

    private func modifierKeyCap(_ choice: ModifierChoice) -> some View {
        let selected = selectedModifiers.contains(choice.modifier)
        return Button {
            toggleModifier(choice.modifier)
        } label: {
            Text(choice.symbol).font(.system(size: 12, weight: .medium)).frame(minWidth: 30, minHeight: 30)
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(selected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(!superKeyEnabled || (selected && !canRemoveModifier(choice.modifier)))
        .help(choice.name)
        .accessibilityLabel(choice.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectedModifiers: GlobalShortcutModifiers { SuperKeySupport.modifiers(from: modifierStorage) }
    private var source: SuperKeySource { SuperKeySource.sanitized(sourceRaw) }

    private var sourceBinding: Binding<SuperKeySource> {
        Binding { source } set: { source in
            sourceRaw = source.rawValue
            superKey.syncWithPreferences()
        }
    }

    private func toggleModifier(_ modifier: GlobalShortcutModifiers) {
        var next = selectedModifiers
        if next.contains(modifier) { next.remove(modifier) } else { next.insert(modifier) }
        guard next.hasPrimaryModifier else { return }
        modifierStorage = SuperKeySupport.storageValue(for: next)
        superKey.syncWithPreferences()
    }

    private func canRemoveModifier(_ modifier: GlobalShortcutModifiers) -> Bool {
        var remaining = selectedModifiers
        remaining.remove(modifier)
        return remaining.hasPrimaryModifier
    }

    private var soloBinding: Binding<SuperKeySoloAction> {
        Binding {
            SuperKeySoloAction.sanitized(soloActionRaw)
        } set: { action in
            soloActionRaw = action.rawValue
            superKey.syncWithPreferences()
        }
    }

    private var cleaningModeCard: some View {
        SettingsCard(title: l10n.s.cleaningMenuItem) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(l10n.s.cleaningMenuItem).font(.headline)
                    Spacer()
                    Toggle(l10n.s.cleaningMenuItem, isOn: $cleaningModeEnabled)
                        .labelsHidden()
                        .onChange(of: cleaningModeEnabled) { _, value in
                            FeatureRuntime.shared.finishAvailabilityChange()
                            CleaningModeManager.shared.syncWithPreferences()
                            guard value, !permissions.accessibility else { return }
                            permissions.requestAccessibility()
                            permissions.openAccessibilitySettings()
                        }
                }

                Text(l10n.s.cleaningPanelCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if cleaningModeEnabled {
                    ShortcutPreferenceRow(role: .cleaningMode) {
                        CleaningModeManager.shared.syncWithPreferences()
                    }

                    Divider()

                    Toggle(l10n.s.cleaningKeepScreenVisibleToggle, isOn: $cleaningModeKeepScreenVisible)
                    Text(l10n.s.cleaningKeepScreenVisibleCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
