// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The System Monitor page. The main switch and the module switches sit in
/// the title bar; the page itself links to the menu bar readings and holds
/// what every surface shares: how often readings refresh, and the alerts.
struct MonitorSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.monitorInterval) private var interval = MonitorRefreshRate.balanced.rawValue
    // The alert switches, so an alert's limit unrolls with the page's
    // managed reveal and the card and the rows below move in one transaction.
    @AppStorage(DefaultsKey.monitorAlertCPU) private var alertCPU = false
    @AppStorage(DefaultsKey.monitorAlertCPUTemperature) private var alertCPUTemperature = false
    @AppStorage(DefaultsKey.monitorAlertBatteryTemperature) private var alertBatteryTemperature = false
    @AppStorage(DefaultsKey.monitorAlertMemory) private var alertMemory = false
    @AppStorage(DefaultsKey.monitorAlertDisk) private var alertDisk = false
    @AppStorage(DefaultsKey.monitorAlertBattery) private var alertBattery = false

    private var strings: SystemMonitorSettingsStrings { FeatureStrings.systemMonitorSettings(l10n.language) }

    var body: some View {
        Group {
            if MonitorModules.anyOn {
                page
            } else {
                SettingsFeatureEmptyState(title: l10n.s.tabMonitor, symbol: "cpu",
                                          description: strings.emptyDescription) {
                    Button(SettingsOwnershipStrings.enable(l10n.s.tabMonitor, l10n.language)) {
                        MonitorModules.setOn(true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            SettingsTitleBarItem(id: "system-monitor-activation") { MonitorTitleBarControls() }
        }
        .settingsExpansionAnimation(value: MonitorModules.anyOn)
        // A module switched in the title bar menu brings its alert rows in or
        // takes them away in the same motion as the rest of the page.
        .settingsExpansionAnimation(value: FeatureVisibilitySupport.monitorFeatures.map(\.isAvailable))
        .settingsExpansionAnimation(value: [alertCPU, alertCPUTemperature, alertMemory, alertDisk,
                                            alertBattery, alertBatteryTemperature])
    }

    private var page: some View {
        // A plain stack, not a lazy one: a lazy stack estimates the rows it
        // has not built yet and kept re-measuring this page without settling.
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsCard {
                    MonitorSubpageRow(title: strings.menuBarTitle, caption: strings.menuBarCaption) {
                        SettingsRouter.shared.request(FeatureSettingsDestination(.monitorMenuBar))
                    }
                    Divider()
                    SettingsControlRow(title: strings.refreshTitle, caption: refreshCaption) {
                        Picker(strings.refreshTitle, selection: $interval) {
                            ForEach(MonitorRefreshRate.allCases, id: \.self) { rate in
                                Text(title(for: rate)).tag(rate.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                SettingsCard(title: FeatureStrings.monitorAlerts(l10n.language).section,
                             caption: FeatureStrings.monitorAlerts(l10n.language).caption) {
                    MonitorAlertsControls()
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .onAppear { interval = Defaults.sanitizedMonitorInterval(interval) }
    }

    private var rate: MonitorRefreshRate {
        MonitorRefreshRate(rawValue: Defaults.sanitizedMonitorInterval(interval)) ?? .balanced
    }

    private func title(for rate: MonitorRefreshRate) -> String {
        switch rate {
        case .fast: return strings.refreshFast
        case .balanced: return strings.refreshBalanced
        case .energySaver: return strings.refreshSaver
        }
    }

    private var refreshCaption: String {
        switch rate {
        case .fast: return strings.refreshFastCaption
        case .balanced: return strings.refreshBalancedCaption
        case .energySaver: return strings.refreshSaverCaption
        }
    }
}

/// How often readings refresh, stored as the seconds between samples.
enum MonitorRefreshRate: Int, CaseIterable {
    case fast = 1
    case balanced = 2
    case energySaver = 5
}

/// The System Monitor's modules as one switch: off turns every module off
/// and remembers which were on, so turning it back on restores the same set.
@MainActor
enum MonitorModules {
    /// Modules this Mac can run; the rest never show.
    static var supported: [AppFeature] {
        FeatureVisibilitySupport.monitorFeatures.filter(\.isHardwareSupported)
    }

    static var anyOn: Bool { supported.contains(where: \.isAvailable) }

    static func setOn(_ on: Bool) {
        let defaults = UserDefaults.standard
        if on {
            let saved = Set(defaults.stringArray(forKey: DefaultsKey.monitorModulesBeforeOff) ?? [])
            // Fan control is a beta, so it only comes back if it was on: the
            // fallback, for nothing saved or nothing saved still supported,
            // is every supported module but fan control.
            let fallback = supported.filter { $0 != .fanControl }
            let remembered = supported.filter { saved.contains($0.rawValue) }
            let restore = remembered.isEmpty ? fallback : remembered
            FeatureRuntime.shared.setAvailable(restore.isEmpty ? supported : restore, true)
        } else {
            let enabled = supported.filter(\.isAvailable)
            defaults.set(enabled.map(\.rawValue), forKey: DefaultsKey.monitorModulesBeforeOff)
            FeatureRuntime.shared.setAvailable(supported, false)
        }
        settingsFinishAvailabilityChange()
    }
}

/// The module menu and the main switch, laid out like the other pages'
/// title bar controls.
private struct MonitorTitleBarControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @State private var showingMenu = false
    /// A click on the menu button while the menu is open first closes it as
    /// a click outside; this keeps that same click from opening it again.
    @State private var menuClosedAt = Date.distantPast

    var body: some View {
        let isOn = MonitorModules.anyOn
        HStack(spacing: 6) {
            if isOn { menuButton }
            SettingsTitleBarSwitch(title: l10n.s.tabMonitor, isOn: isOn) { MonitorModules.setOn($0) }
        }
        .padding(.horizontal, 8)
        .onChange(of: isOn) { _, on in
            if !on { showingMenu = false }
        }
    }

    private var menuButton: some View {
        let label = FeatureStrings.recorder(l10n.language).moreOptions
        return Button {
            guard Date().timeIntervalSince(menuClosedAt) > 0.3 else { return }
            showingMenu.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(showingMenu ? Color.accentColor : Color.primary)
        }
        .buttonStyle(FlatSettingsOptionsButtonStyle())
        // The page hands this button first focus as it opens; no ring for that.
        .focusEffectDisabled()
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(showingMenu ? .isSelected : [])
        .popover(isPresented: $showingMenu, arrowEdge: .bottom) { MonitorModulesMenu() }
        .onChange(of: showingMenu) { _, open in
            if !open { menuClosedAt = Date() }
        }
    }
}

/// One switch per module this Mac supports, each with its line of help.
private struct MonitorModulesMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    var body: some View {
        let hub = FeatureStrings.hub(l10n.language)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(MonitorModules.supported, id: \.self) { feature in
                SettingsMenuToggleRow(title: title(feature, hub: hub), help: help(feature, hub: hub),
                                      isOn: Binding(get: { feature.isAvailable }, set: { enabled in
                    FeatureRuntime.shared.setAvailable([feature], enabled)
                    settingsFinishAvailabilityChange()
                }))
            }
        }
        .padding(6)
        .frame(width: 320)
    }

    private func title(_ feature: AppFeature, hub: FeatureHubStrings) -> String {
        let title = feature.hubTitle(l10n.s, hub: hub)
        return feature.isBeta ? "\(title) (\(l10n.s.betaBadge))" : title
    }

    private func help(_ feature: AppFeature, hub: FeatureHubStrings) -> String {
        let description = feature.hubDescription(hub)
        return feature.isBeta ? "\(description) \(l10n.s.betaFeatureWarning)" : description
    }
}

/// A row that opens a subpage, with its chevron.
struct MonitorSubpageRow: View {
    let title: String
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
