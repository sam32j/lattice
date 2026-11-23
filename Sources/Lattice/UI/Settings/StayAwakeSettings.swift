// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// The Stay Awake page: the session, what starts one by itself, what a
/// session does while it runs, and the lid and battery rules. The main
/// switch and the countdown option sit in the title bar. Anything that needs
/// more room opens in a sheet, so the page never grows a block in place.
struct StayAwakeSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var hotkeys = HotkeyManager.shared
    @AppStorage(DefaultsKey.batteryLimit) private var batteryLimit = 10
    @AppStorage(DefaultsKey.keepAwakeAllowDisplaySleep) private var allowDisplaySleep = false
    @AppStorage(DefaultsKey.keepAwakePauseWhenLocked) private var pauseWhenLocked = false
    @AppStorage(DefaultsKey.keepAwakeAutomationRequireAll) private var requireAll = false
    @AppStorage(DefaultsKey.keepAwakeExternalDisplay) private var externalDisplay = false
    @AppStorage(DefaultsKey.keepAwakeConnectedToPower) private var connectedToPower = false
    @AppStorage(DefaultsKey.keepAwakeRunningApps) private var runningApps = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleEnabled) private var mouseJiggle = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleInterval) private var mouseJiggleInterval = 5
    @AppStorage(DefaultsKey.hotkeyEnabled) private var hotkeyEnabled = true
    @State private var pickingTime = false
    /// Lid setup usually finishes within milliseconds; its caption and the
    /// disabled switch wait until it has run long enough to be worth showing.
    @State private var showsSetupProgress = false
    private static let setupProgressDelay: TimeInterval = 0.4

    private var strings: StayAwakeSettingsStrings { FeatureStrings.stayAwakeSettings(l10n.language) }
    private var automation: KeepAwakeAutomationStrings { FeatureStrings.keepAwakeAutomation(l10n.language) }
    private var selectedConditionCount: Int {
        [externalDisplay, connectedToPower, runningApps].filter { $0 }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StayAwakeSessionCard(pickingTime: $pickingTime)
                    .settingsSectionAnchor(.keepAwake, cornerRadius: 16)
                automationCard
                whileAwakeCard
                if PowerSampler.hasInternalBattery {
                    lidBatteryCard
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .onAppear {
            awake.refreshPasswordlessStatus()
            batteryLimit = Defaults.sanitizedBatteryLimit(batteryLimit)
            mouseJiggleInterval = Defaults.sanitizedKeepAwakeMouseJiggleInterval(mouseJiggleInterval)
            if awake.clamshellSetupInProgress { scheduleSetupProgress() }
        }
        .onChange(of: awake.clamshellSetupInProgress) { _, inProgress in
            if inProgress { scheduleSetupProgress() } else { showsSetupProgress = false }
        }
        // Every revealed row and the cards under it move in one transaction.
        .settingsExpansionAnimation(value: [pickingTime, runningApps, selectedConditionCount > 1, mouseJiggle,
                                            permissions.accessibility, awake.clamshellPreferred,
                                            awake.clamshellSetupFailed, hotkeyEnabled && hotkeys.registrationFailed])
    }

    private func scheduleSetupProgress() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.setupProgressDelay) {
            if awake.clamshellSetupInProgress { showsSetupProgress = true }
        }
    }

    // MARK: Start automatically

    private var automationCard: some View {
        SettingsCard(title: strings.autoTitle, caption: automationCaption, headerAccessory: {
            // In the header, so choosing a second condition never grows the card.
            if selectedConditionCount > 1 {
                Picker(selection: $requireAll) {
                    Text(automation.matchAny).tag(false)
                    Text(automation.matchAll).tag(true)
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .onChange(of: requireAll) { _, _ in awake.automationPreferencesDidChange() }
            }
        }) {
            KeepAwakeConditionTiles()
            if runningApps {
                StayAwakeAppsList()
                    .transition(.settingsReveal)
            }
        }
    }

    private var automationCaption: String {
        switch StayAwakeAutomationCaption.make(selectedCount: selectedConditionCount, requireAll: requireAll) {
        case .none: return strings.autoNone
        case .one: return strings.autoOne
        case .combined(let all): return automation.caption(requireAll: all)
        }
    }

    // MARK: While awake

    private var whileAwakeCard: some View {
        SettingsCard(title: strings.whileAwakeTitle, caption: strings.whileAwakeCaption) {
            SettingsRow(symbol: "display", title: strings.displaySleepTitle, caption: strings.displaySleepCaption) {
                Toggle(strings.displaySleepTitle, isOn: $allowDisplaySleep).labelsHidden()
            }
            SettingsRow(symbol: "cursorarrow.motionlines", title: strings.pointerTitle, caption: strings.pointerCaption) {
                PermissionGatedToggle(strings.pointerTitle, isOn: $mouseJiggle).labelsHidden()
            }
            if mouseJiggle {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsControlRow(title: strings.pointerInterval) {
                        Picker(strings.pointerInterval, selection: $mouseJiggleInterval) {
                            ForEach(Defaults.allowedKeepAwakeMouseJiggleIntervals, id: \.self) { minutes in
                                Text(Self.intervalTitle(minutes: minutes, locale: l10n.language.formattingLocale()))
                                    .tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                    }
                    if !permissions.accessibility {
                        PermissionRow(kind: .accessibility)
                            .transition(.settingsReveal)
                    }
                }
                .padding(.leading, settingsRowTextInset)
                .transition(.settingsReveal)
            }
            SettingsRow(symbol: "lock.fill", title: strings.pauseLockedTitle, caption: strings.pauseLockedCaption) {
                Toggle(strings.pauseLockedTitle, isOn: $pauseWhenLocked).labelsHidden()
            }
        }
    }

    // MARK: Lid & battery

    private var lidBatteryCard: some View {
        SettingsCard(title: strings.lidBatteryTitle) {
            SettingsRow(symbol: "laptopcomputer", title: strings.lidTitle, caption: lidCaption) {
                Toggle(strings.lidTitle, isOn: $awake.clamshellPreferred)
                    .labelsHidden()
                    .disabled(showsSetupProgress)
            }
            .help(strings.lidHelp)
            if awake.clamshellSetupFailed {
                Text(l10n.s.sudoersFailed)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, settingsRowTextInset)
                    .transition(.settingsReveal)
            }
            if awake.clamshellPreferred {
                SettingsControlRow(title: strings.dimTitle, caption: strings.dimCaption) {
                    Toggle(strings.dimTitle, isOn: $awake.dimScreenOnLidClose).labelsHidden()
                }
                .padding(.leading, settingsRowTextInset)
                .transition(.settingsReveal)
            }
            SettingsRow(symbol: "battery.25percent", title: strings.batteryTitle, caption: strings.batteryCaption) {
                Picker(strings.batteryTitle, selection: $batteryLimit) {
                    Text(l10n.s.batteryNever).tag(0)
                    ForEach([5, 10, 15, 20], id: \.self) { percent in
                        Text(String(format: strings.batteryBelowFormat, percent)).tag(percent)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    /// "1 minute", "5 minutes", in the app's language.
    static func intervalTitle(minutes: Int, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)"
    }

    private var lidCaption: String {
        switch StayAwakeLidCaption.make(inProgress: showsSetupProgress, preferred: awake.clamshellPreferred,
                                        isActive: awake.isActive, passwordless: awake.passwordlessClamshell) {
        case .configuring: return l10n.s.configuring
        case .onDuringSession: return strings.lidOnNow
        case .appliesToSessions: return strings.lidEverySession
        case .ready: return strings.lidNoPassword
        case .needsPassword: return strings.lidNeedsPassword
        }
    }
}

/// The Stay Awake page's title bar menu.
struct StayAwakeSettingsMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.showCountdown) private var showCountdown = false

    var body: some View {
        let strings = FeatureStrings.stayAwakeSettings(l10n.language)
        VStack(alignment: .leading, spacing: 0) {
            SettingsMenuToggleRow(title: strings.countdownTitle, help: strings.countdownCaption, isOn: $showCountdown)
        }
        .padding(6)
        .frame(width: 300)
    }
}
