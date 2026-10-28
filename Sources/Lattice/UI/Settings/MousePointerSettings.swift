import SwiftUI

extension MouseSettings {
    // MARK: - Focus follows mouse

    var focusFollowsMouseControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: "macwindow.and.cursorarrow", title: l10n.s.focusFollowsMouseName,
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
                    sliderRow(l10n.s.focusFollowsMouseDelay,
                              value: focusFollowsMouseDelayBinding,
                              range: Double(FocusFollowsMouseSupport.delayRange.lowerBound)
                                  ... Double(FocusFollowsMouseSupport.delayRange.upperBound),
                              step: 50,
                              readout: "\(focusFollowsMouseDelay) ms")
                    SettingsToggleRow(title: l10n.s.focusFollowsMouseRaise, isOn: $focusFollowsMouseRaise)
                    if !focusFollowsMouseRaise {
                        SettingsToggleRow(title: l10n.s.focusFollowsMouseWaitForStop, isOn: $focusFollowsMouseWaitForStop)
                    }
                    MouseExceptionsList(scope: .focusFollowsMouse)
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    // MARK: - Acceleration, side buttons, click filter, middle click

    var accelerationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: "cursorarrow.motionlines", title: l10n.s.mouseAccelerationName,
                        caption: l10n.s.mouseAccelerationCaption) {
                Toggle(l10n.s.mouseAccelerationName, isOn: $mouseAccelerationDisabled)
                    .labelsHidden()
                    .onChange(of: mouseAccelerationDisabled) { _, _ in
                        MouseAccelerationService.shared.syncWithPreferences()
                    }
            }
        }
    }

    var navigationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: "arrowshape.turn.up.left", title: l10n.s.mouseNavigationEnable,
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
                    .padding(.leading, settingsRowTextInset)
            }
        }
    }

    var clickFilterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: "cursorarrow.click.badge.clock", title: mouseClickDebounceText.title,
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
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    var middleClickCard: some View {
        SettingsCard(title: l10n.s.middleClickSection) {
            SettingsRow(symbol: "hand.tap", title: l10n.s.middleClickEnable,
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
                    SettingsControlRow(title: l10n.s.middleClickTapPicker) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .frame(width: 20, height: 20)
                                .overlay { StatusTooltip(message: middleClick.systemDragGestureConflict
                                    ? InputSettingsStrings.trackpadDragConflict(l10n.language)
                                    : l10n.s.middleClickTapCaption) }
                                .accessibilityLabel(middleClick.systemDragGestureConflict
                                    ? InputSettingsStrings.trackpadDragConflict(l10n.language)
                                    : l10n.s.middleClickTapCaption)
                            Picker(l10n.s.middleClickTapPicker, selection: Binding(
                                get: { MiddleClickSupport.availableTapSelection(middleClickTapFingers,
                                    systemDragEnabled: middleClick.systemDragGestureConflict) },
                                set: { middleClickTapFingers = $0 })) {
                                Text(l10n.s.middleClickTapOff).tag(0)
                                if !middleClick.systemDragGestureConflict {
                                    Text(l10n.s.middleClickTapThreeFingers).tag(3)
                                }
                                Text(l10n.s.middleClickTapFourFingers).tag(4)
                            }
                            .labelsHidden().pickerStyle(.menu).fixedSize()
                            .onChange(of: middleClickTapFingers) { _, _ in middleClick.syncWithPreferences() }
                        }
                        .frame(width: 220, alignment: .trailing)
                    }
                    if middleClick.touchDeviceMissing {
                        Text(l10n.s.middleClickNoTrackpad)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, settingsRowTextInset)
                MouseExceptionsList(scope: .middleClick)
                    .padding(.leading, settingsRowTextInset)
            }
        }
    }
}
