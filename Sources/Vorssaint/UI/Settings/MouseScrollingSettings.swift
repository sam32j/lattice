import SwiftUI

extension MouseSettings {
    // MARK: - Scrolling

    var scrollControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: "arrow.up.arrow.down", title: l10n.s.invertVerticalScroll,
                        caption: l10n.s.scrollTrackpadNote) {
                PermissionGatedToggle(l10n.s.invertVerticalScroll, isOn: $invertVertical)
                    .labelsHidden()
                    .onChange(of: invertVertical) { _, _ in
                        ScrollInverter.shared.syncWithPreferences()
                        if scrollDirectionEnabled { permissions.requestAccessibility() }
                    }
            }
            SettingsRow(symbol: "arrow.left.arrow.right", title: l10n.s.invertHorizontalScroll) {
                PermissionGatedToggle(l10n.s.invertHorizontalScroll, isOn: $invertHorizontal)
                    .labelsHidden()
                    .onChange(of: invertHorizontal) { _, _ in
                        ScrollInverter.shared.syncWithPreferences()
                        if scrollDirectionEnabled { permissions.requestAccessibility() }
                    }
            }
            SettingsRow(symbol: "arrow.left.and.right", title: l10n.s.scrollHorizontalName,
                        caption: l10n.s.scrollHorizontalCaption) {
                PermissionGatedToggle(l10n.s.scrollHorizontalName, isOn: $horizontalScrollEnabled)
                    .labelsHidden()
                    .onChange(of: horizontalScrollEnabled) { _, _ in
                        ScrollInverter.shared.syncWithPreferences()
                        if scrollDirectionEnabled { permissions.requestAccessibility() }
                    }
            }
            if horizontalScrollEnabled {
                modifierKeys.padding(.leading, settingsRowTextInset)
            }
            MouseExceptionsList(scope: .scrollDirection)
                .disabled(!scrollDirectionEnabled)
        }
    }

    /// Follow-up controls share the trailing control column.
    var modifierKeys: some View {
        let modifierStrings = FeatureStrings.quitProtection(l10n.language)
        let choices: [(ScrollHorizontalModifier, String, String)] = [
            (.shift, "⇧", modifierStrings.shiftKey),
            (.option, "⌥", modifierStrings.optionKey),
            (.control, "⌃", modifierStrings.controlKey),
            (.command, "⌘", l10n.s.scrollHorizontalCommandKey),
        ]
        return SettingsControlRow(title: l10n.s.scrollHorizontalModifierLabel) {
            Picker(l10n.s.scrollHorizontalModifierLabel, selection: $horizontalScrollModifier) {
                ForEach(choices, id: \.0) { modifier, glyph, name in
                    Text("\(glyph) \(name)").tag(modifier)
                }
            }
            .labelsHidden().pickerStyle(.menu)
            .frame(width: 220, alignment: .trailing)
        }
    }

    // MARK: - Smooth scrolling

    var smoothScrollControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: "scroll", title: l10n.s.smoothScrollName, caption: l10n.s.smoothScrollCaption) {
                PermissionGatedToggle(l10n.s.smoothScrollName, isOn: $smoothScrollEnabled)
                    .labelsHidden()
                    .onChange(of: smoothScrollEnabled) { _, enabled in
                        SmoothScrollService.shared.syncWithPreferences()
                        if enabled { permissions.requestAccessibility() }
                    }
            }
            if smoothScrollEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow(l10n.s.smoothScrollStepLabel,
                              value: smoothScrollStepBinding,
                              range: Double(SmoothScrollSupport.stepRange.lowerBound)
                                  ... Double(SmoothScrollSupport.stepRange.upperBound),
                              step: 10,
                              readout: "\(SmoothScrollSupport.sanitizedStep(smoothScrollStep))")
                    sliderRow(l10n.s.smoothScrollResponseLabel,
                                  value: smoothScrollResponseBinding,
                                  range: Double(SmoothScrollSupport.responseRange.lowerBound)
                                      ... Double(SmoothScrollSupport.responseRange.upperBound),
                                  step: 5,
                                  readout: "\(SmoothScrollSupport.sanitizedResponse(smoothScrollResponse))%")
                    sliderRow(l10n.s.smoothScrollCoastLabel,
                                  value: smoothScrollCoastBinding,
                                  range: Double(SmoothScrollSupport.coastRange.lowerBound)
                                      ... Double(SmoothScrollSupport.coastRange.upperBound),
                                  step: 5,
                                  readout: "\(SmoothScrollSupport.sanitizedCoast(smoothScrollCoast))%")
                    MouseExceptionsList(scope: .smoothScroll)
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    // MARK: - Linear scrolling

    var linearScrollControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: AppFeature.linearScroll.symbolName, title: l10n.s.linearScrollName,
                        caption: l10n.s.linearScrollCaption) {
                PermissionGatedToggle(l10n.s.linearScrollName, isOn: $linearScrollEnabled)
                    .labelsHidden()
                    .onChange(of: linearScrollEnabled) { _, enabled in
                        ScrollInverter.shared.syncWithPreferences()
                        if enabled { permissions.requestAccessibility() }
                    }
            }
            if linearScrollEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow(l10n.s.linearScrollLinesLabel,
                              value: linearScrollLinesBinding,
                              range: Double(ScrollWheelSupport.linesPerNotchRange.lowerBound)
                                  ... Double(ScrollWheelSupport.linesPerNotchRange.upperBound),
                              step: 1,
                              readout: "\(ScrollWheelSupport.sanitizedLinesPerNotch(linearScrollLines))")
                    MouseExceptionsList(scope: .linearScroll)
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, readout: String) -> some View {
        SettingsSliderRow(title: title, value: value, range: range, step: step, readout: readout)
    }

}
