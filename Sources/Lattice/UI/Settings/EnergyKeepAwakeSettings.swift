// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct EnergyKeepAwakeSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration = 0
    @AppStorage(DefaultsKey.batteryLimit) private var batteryLimit = 10
    @AppStorage(DefaultsKey.keepAwakeAutoStart) private var keepAwakeAutoStart = false
    @AppStorage(DefaultsKey.keepAwakeRightClickToggle) private var keepAwakeRightClickToggle = false
    @AppStorage(DefaultsKey.keepAwakeAllowDisplaySleep) private var keepAwakeAllowDisplaySleep = false
    @AppStorage(DefaultsKey.keepAwakePauseWhenLocked) private var keepAwakePauseWhenLocked = false
    @AppStorage(DefaultsKey.keepAwakeAutomationRequireAll) private var keepAwakeAutomationRequireAll = false
    @AppStorage(DefaultsKey.showCountdown) private var showCountdown = false
    @AppStorage(DefaultsKey.keepAwakeIconTint) private var keepAwakeIconTint = KeepAwakeIconTint.orange.rawValue
    @AppStorage(DefaultsKey.keepAwakeActiveIcon) private var keepAwakeActiveIcon = KeepAwakeActiveIcon.lattice.rawValue
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleEnabled) private var keepAwakeMouseJiggle = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleInterval) private var keepAwakeMouseJiggleInterval = 5
    @ObservedObject private var hotkeys = HotkeyManager.shared
    @AppStorage(DefaultsKey.hotkeyEnabled) private var hotkeyEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            keepAwakeCard.settingsSectionAnchor(.keepAwake, cornerRadius: 16)
            keepAwakeOptionsCard
        }
        .onAppear {
            defaultDuration = Defaults.sanitizedDefaultDuration(defaultDuration)
            batteryLimit = Defaults.sanitizedBatteryLimit(batteryLimit)
            keepAwakeIconTint = Defaults.sanitizedKeepAwakeIconTint(keepAwakeIconTint).rawValue
            keepAwakeActiveIcon = Defaults.sanitizedKeepAwakeActiveIcon(keepAwakeActiveIcon).rawValue
            keepAwakeMouseJiggleInterval = Defaults.sanitizedKeepAwakeMouseJiggleInterval(keepAwakeMouseJiggleInterval)
        }
        .settingsExpansionAnimation(value: [keepAwakeMouseJiggle, awake.clamshellPreferred,
            awake.clamshellSetupFailed, permissions.accessibility])
    }

    // MARK: - Keep awake

    /// The feature itself: what it is doing now, the switch, the default
    /// duration and the conditions that start it by themselves.
    private var keepAwakeCard: some View {
        SettingsCard {
            // A running countdown only while there is one to run down; an
            // automatic session names its condition instead, as in the panel.
            if awake.isActive, awake.sessionTrigger != .automation, let end = awake.endDate {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    sessionRow(status: "\(l10n.s.keepAwakeEndsIn) \(KeepAwakeCard.remainingText(until: end))")
                }
            } else {
                sessionRow(status: sessionStatus)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.s.defaultDurationLabel)
                    .font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                    ForEach(DurationPicker.choices, id: \.self) { minutes in
                        durationChip(minutes)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(automationStrings.automationSection)
                    .font(.subheadline.weight(.medium))
                Text(automationStrings.caption(requireAll: keepAwakeAutomationRequireAll))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                KeepAwakeAutomationEditor()
            }
            SettingsRow(symbol: "lock.fill", title: automationStrings.pauseWhenLockedToggle,
                        caption: automationStrings.pauseWhenLockedCaption) {
                Toggle(automationStrings.pauseWhenLockedToggle, isOn: $keepAwakePauseWhenLocked)
                    .labelsHidden()
            }
            Divider()
            ShortcutPreferenceRow(role: .keepAwake, label: l10n.s.hotkeyToggle,
                                  symbolName: "keyboard") {
                HotkeyManager.shared.syncWithPreferences()
            }
            if hotkeyEnabled, hotkeys.registrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// The feature's name, what it is doing right now and its switch.
    private func sessionRow(status: String) -> some View {
        SettingsRow(symbol: "bolt.fill", title: l10n.s.keepAwakeTitle, caption: status) {
            Toggle(l10n.s.keepAwakeTitle, isOn: sessionBinding)
                .labelsHidden()
        }
    }

    private var sessionStatus: String {
        guard awake.isActive else { return l10n.s.keepAwakeNormalRules }
        if awake.sessionTrigger == .automation {
            return automationStrings.activeStatus(for: awake.activeAutomationConditions)
        }
        return l10n.s.keepAwakeUntilDisabled
    }

    private var sessionBinding: Binding<Bool> {
        Binding(
            get: { awake.isActive },
            set: { on in
                if on {
                    awake.startLastPick()
                } else if awake.isActive {
                    awake.toggle()
                }
            }
        )
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = defaultDuration == minutes
        return Button {
            defaultDuration = minutes
            // A chosen default is the newest pick, so the switch starts it.
            UserDefaults.standard.set(false, forKey: DefaultsKey.keepAwakeSwitchUsesUntil)
        } label: {
            Text(DurationPicker.title(for: minutes, l10n.s))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Everything else Keep Awake can do, one row each.
    private var keepAwakeOptionsCard: some View {
        SettingsCard(title: l10n.s.keepAwakeOptions) {
            SettingsRow(symbol: "play.circle", title: l10n.s.keepAwakeAutoStart,
                        caption: l10n.s.keepAwakeAutoStartCaption) {
                Toggle(l10n.s.keepAwakeAutoStart, isOn: $keepAwakeAutoStart).labelsHidden()
            }
            SettingsRow(symbol: "cursorarrow.click.2", title: l10n.s.keepAwakeRightClickToggle,
                        caption: l10n.s.keepAwakeRightClickToggleCaption) {
                Toggle(l10n.s.keepAwakeRightClickToggle, isOn: $keepAwakeRightClickToggle).labelsHidden()
            }
            SettingsRow(symbol: "timer", title: l10n.s.showCountdown) {
                Toggle(l10n.s.showCountdown, isOn: $showCountdown).labelsHidden()
            }
            SettingsRow(symbol: "display", title: displaySleepStrings.allowDisplaySleep,
                        caption: displaySleepStrings.allowDisplaySleepCaption) {
                Toggle(displaySleepStrings.allowDisplaySleep, isOn: $keepAwakeAllowDisplaySleep).labelsHidden()
            }
            SettingsRow(symbol: "cursorarrow.motionlines", title: l10n.s.keepAwakeMouseJiggle,
                        caption: l10n.s.keepAwakeMouseJiggleCaption) {
                PermissionGatedToggle(l10n.s.keepAwakeMouseJiggle, isOn: $keepAwakeMouseJiggle).labelsHidden()
            }
            if keepAwakeMouseJiggle {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(l10n.s.keepAwakeMouseJiggleInterval)
                        Spacer()
                        KeepAwakeMouseJiggleIntervalPicker(selection: $keepAwakeMouseJiggleInterval)
                    }
                    if !permissions.accessibility {
                        PermissionRow(kind: .accessibility)
                    }
                }
                .padding(.leading, settingsRowTextInset)
            }
            Divider()
            KeepAwakeIconPicker(iconValue: $keepAwakeActiveIcon, tintValue: $keepAwakeIconTint)
            if PowerSampler.hasInternalBattery {
                Divider()
                SettingsRow(symbol: "battery.25percent", title: l10n.s.batteryDisableBelow,
                            caption: l10n.s.batteryProtectionCaption) {
                    Picker(l10n.s.batteryDisableBelow, selection: $batteryLimit) {
                        Text(l10n.s.batteryNever).tag(0)
                        Text("5%").tag(5)
                        Text("10%").tag(10)
                        Text("15%").tag(15)
                        Text("20%").tag(20)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            Divider()
            SettingsRow(symbol: "laptopcomputer", title: l10n.s.clamshellTitle, caption: clamshellCaption) {
                Toggle(l10n.s.clamshellTitle, isOn: $awake.clamshellPreferred)
                    .labelsHidden()
                    .disabled(awake.clamshellSetupInProgress)
            }
            if awake.clamshellSetupFailed {
                Text(l10n.s.sudoersFailed)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, settingsRowTextInset)
            }
            if awake.clamshellPreferred {
                SettingsRow(symbol: "sun.min", title: l10n.s.dimScreenOnLidCloseTitle,
                            caption: l10n.s.dimScreenOnLidCloseCaption) {
                    Toggle(l10n.s.dimScreenOnLidCloseTitle, isOn: $awake.dimScreenOnLidClose)
                        .labelsHidden()
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    private var clamshellCaption: String {
        awake.clamshellSetupInProgress ? l10n.s.configuring : l10n.s.clamshellExplanation
    }

    private var automationStrings: KeepAwakeAutomationStrings {
        FeatureStrings.keepAwakeAutomation(l10n.language)
    }

    private var displaySleepStrings: KeepAwakeDisplaySleepStrings {
        FeatureStrings.keepAwakeDisplaySleep(l10n.language)
    }
}
