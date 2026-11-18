import SwiftUI

extension MouseSettings {
    // MARK: - Focus follows mouse

    var focusFollowsMouseControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsControlRow(title: l10n.s.focusFollowsMouseName,
                               caption: l10n.s.focusFollowsMouseCaption) {
                PermissionGatedToggle(l10n.s.focusFollowsMouseName, isOn: $focusFollowsMouseEnabled)
                    .labelsHidden()
                    .onChange(of: focusFollowsMouseEnabled) { _, enabled in
                        FocusFollowsMouseService.shared.syncWithPreferences()
                        if enabled { Permissions.shared.requestAccessibility() }
                    }
            }
            if focusFollowsMouseEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsControlRow(title: l10n.s.focusFollowsMouseDelay) {
                        Picker(l10n.s.focusFollowsMouseDelay, selection: focusFollowsMouseDelayPresetBinding) {
                            ForEach(FocusFollowsMouseSupport.DelayPreset.allCases, id: \.self) { preset in
                                Text(preset.title(l10n.language)).tag(preset)
                            }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                    }
                    SettingsToggleRow(title: l10n.s.focusFollowsMouseRaise, isOn: $focusFollowsMouseRaise)
                    if !focusFollowsMouseRaise {
                        SettingsToggleRow(title: l10n.s.focusFollowsMouseWaitForStop, isOn: $focusFollowsMouseWaitForStop)
                    }
                    MouseExceptionsList(scope: .focusFollowsMouse,
                                        title: InputSettingsStrings.focusFollowsMouseExceptionsTitle(l10n.language))
                }
            }
        }
    }

    // MARK: - Acceleration, side buttons, click filter, middle click

    var accelerationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsControlRow(title: l10n.s.mouseAccelerationName,
                               caption: l10n.s.mouseAccelerationCaption) {
                Toggle(l10n.s.mouseAccelerationName, isOn: $mouseAccelerationDisabled)
                    .labelsHidden()
                    .onChange(of: mouseAccelerationDisabled) { _, _ in
                        settingsApplyAfterSwitch { MouseAccelerationService.shared.syncWithPreferences() }
                    }
            }
        }
    }

    var navigationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsControlRow(title: l10n.s.mouseNavigationEnable,
                               caption: InputSettingsStrings.text(.sideButtonsHelp, l10n.language)) {
                PermissionGatedToggle(l10n.s.mouseNavigationEnable, isOn: $mouseNavigationEnabled)
                    .labelsHidden()
                    .onChange(of: mouseNavigationEnabled) { _, enabled in
                        MouseNavigationService.shared.syncWithPreferences()
                        if enabled { permissions.requestAccessibility() }
                    }
            }
            if mouseNavigationEnabled {
                MouseExceptionsList(scope: .navigation)
            }
        }
    }

    var clickFilterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsControlRow(title: mouseClickDebounceText.title,
                               caption: mouseClickDebounceText.caption) {
                PermissionGatedToggle(mouseClickDebounceText.title, isOn: $mouseClickDebounceEnabled)
                    .labelsHidden()
                    .onChange(of: mouseClickDebounceEnabled) { _, enabled in
                        MouseClickDebounceService.shared.syncWithPreferences()
                        if enabled { permissions.requestAccessibility() }
                    }
            }
            if mouseClickDebounceEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: mouseClickDebounceWindowBinding,
                            in: Defaults.allowedMouseClickDebounceWindowRange,
                            step: 1) {
                        HStack {
                            Text(mouseClickDebounceText.windowLabel)
                            Spacer()
                            Text("\(Defaults.sanitizedMouseClickDebounceWindow(mouseClickDebounceWindow)) ms")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .help(mouseClickDebounceText.windowCaption)
                }
            }
        }
    }

    var middleClickCard: some View {
        let strings = InputSettingsStrings.middleClick(l10n.language)
        let dragOwnsThree = middleClick.systemDragGestureConflict
        let tapOwnsThree = middleClick.systemOwnsThreeFingerTap
        return SettingsCard(symbol: "hand.tap", title: l10n.s.middleClickSection) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsControlRow(title: l10n.s.middleClickEnable,
                                   caption: l10n.s.middleClickEnableCaption) {
                    PermissionGatedToggle(l10n.s.middleClickEnable, isOn: $middleClickEnabled)
                        .labelsHidden()
                        .onChange(of: middleClickEnabled) { _, enabled in
                            MiddleClickService.shared.syncWithPreferences()
                            if enabled { permissions.requestAccessibility() }
                        }
                }
                if middleClickEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        fingerPickerRow(title: strings.clickWith,
                                        note: dragOwnsThree ? strings.clickTaken : nil) {
                            SettingsPopUpPicker(title: strings.clickWith, options: [
                                threeFingerOption(available: !dragOwnsThree),
                                .init(value: 4, title: l10n.s.middleClickTapFourFingers),
                            ], selection: Binding(
                                get: { MiddleClickSupport.availableClickSelection(middleClickClickFingers,
                                                                                  systemDragEnabled: dragOwnsThree) },
                                set: { middleClickClickFingers = $0 }))
                            .fixedSize()
                            .onChange(of: middleClickClickFingers) { _, _ in middleClick.syncWithPreferences() }
                        }
                        fingerPickerRow(title: l10n.s.middleClickTapPicker,
                                        note: tapOwnsThree ? strings.tapTaken : nil) {
                            SettingsPopUpPicker(title: l10n.s.middleClickTapPicker, options: [
                                .init(value: 0, title: l10n.s.middleClickTapOff),
                                threeFingerOption(available: !tapOwnsThree),
                                .init(value: 4, title: l10n.s.middleClickTapFourFingers),
                            ], selection: Binding(
                                get: { MiddleClickSupport.availableTapSelection(middleClickTapFingers,
                                                                                systemOwnsThreeFingerTap: tapOwnsThree) },
                                set: { middleClickTapFingers = $0 }))
                            .fixedSize()
                            .help(l10n.s.middleClickTapCaption)
                            .onChange(of: middleClickTapFingers) { _, _ in middleClick.syncWithPreferences() }
                        }
                        if middleClick.touchDeviceMissing {
                            Text(l10n.s.middleClickNoTrackpad)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        MouseExceptionsList(scope: .middleClick)
                    }
                }
            }
            .padding(.leading, settingsRowTextInset)
        }
    }

    /// A finger picker with, while macOS is using its three-finger choice, an
    /// amber line under the title saying so. It belongs to the row, so the
    /// rows keep their rhythm instead of being split by a note between them.
    private func fingerPickerRow<Control: View>(title: String, note: String?,
                                               @ViewBuilder picker: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            picker()
        }
    }

    /// Always listed so the menu keeps its shape, and greyed while macOS is
    /// using three fingers; the row's amber note says so.
    private func threeFingerOption(available: Bool) -> SettingsPopUpPicker<Int>.Option {
        .init(value: 3, title: l10n.s.middleClickTapThreeFingers, isEnabled: available)
    }
}

extension FocusFollowsMouseSupport.DelayPreset {
    /// Kept beside the picker: the support file is also built into the
    /// tests, which do not carry the Settings strings.
    func title(_ language: AppLanguage) -> String {
        let names = InputSettingsStrings.hoverDelayNames(language)
        return names[Self.allCases.firstIndex(of: self) ?? 0]
    }
}
