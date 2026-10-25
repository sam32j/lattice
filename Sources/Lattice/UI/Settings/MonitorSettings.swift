// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The "Monitor" settings page: pick what shows next to the menu bar icon, how
/// it looks and how often it refreshes, which blocks appear in the panel, when
/// to warn, and which metrics draw a history graph. Everything is opt-in or
/// reversible, so users keep only what they find useful. The live menu bar
/// preview stays pinned while the choices that change it scroll under it.
struct MonitorSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    @AppStorage(DefaultsKey.menuBarCombineTemperatures) private var combineTemperatures = true
    @AppStorage(DefaultsKey.menuBarSeparateMetrics) private var separateMetrics = false
    @AppStorage(DefaultsKey.menuBarMetricSpacing) private var metricSpacing = "standard"
    @AppStorage(DefaultsKey.menuBarMetricAppearance) private var metricAppearance = "values"
    @AppStorage(DefaultsKey.menuBarHideIconWithMetrics) private var hideIconWithMetrics = false
    @AppStorage(DefaultsKey.monitorInterval) private var interval = 2
    @AppStorage(DefaultsKey.monitorGraphScale) private var graphScale = true
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.networkSpeedUnit) private var networkSpeedUnit = NetworkSpeedUnit.bytes
    @AppStorage(DefaultsKey.monitorMemoryMetric) private var memoryMetric = "used"
    @AppStorage(DefaultsKey.panelShowFanControl) private var showFanControl = true

    var body: some View {
        // A plain stack, not a lazy one: a lazy stack estimates the rows it
        // has not built yet, and with the taller Bars options this page kept
        // it re-measuring and re-anchoring without ever settling, which hung
        // Settings on the first scroll. Pinned headers exist only on lazy
        // stacks, so the preview sits above the scroll view instead, where it
        // also stays in view for the shared units further down that change it.
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.s.monitorMenuBarPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                MenuBarMetricsPreview()
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MonitorModuleSettings()
                    groupHeading(l10n.s.monitorMenuBarSection, symbol: "menubar.rectangle")
                    if MenuBarMetric.order(in: .standard).contains(where: { $0.feature.isAvailable && $0.isAvailableOnCurrentHardware }) {
                        menuBarCard
                    }
                    menuBarStyleCard
                    groupHeading(l10n.s.monitorPanelSection, symbol: "macwindow")
                    panelCard
                    if AppFeature.fanControl.isPresentInControls() {
                        fanControlCard
                            .settingsSectionAnchor(.fanControl, cornerRadius: 16)
                    }
                    groupHeading(SettingsOrganizationStrings.text(.readings, l10n.language), symbol: "slider.horizontal.3")
                    readingsCard
                    alertsCard
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(22)
            }
        }
        .toggleStyle(.switch)
        .onAppear {
            interval = Defaults.sanitizedMonitorInterval(interval)
            metricAppearance = Defaults.sanitizedMenuBarMetricAppearance(metricAppearance)
            if TemperatureUnit(rawValue: temperatureUnit) == nil {
                temperatureUnit = TemperatureUnit.celsius.rawValue
            }
            memoryMetric = Defaults.sanitizedMonitorMemoryMetric(memoryMetric)
        }
    }

    /// Splits the page into what the menu bar shows, what the panel shows,
    /// and what both share, so an option is never read as the other's.
    private func groupHeading(_ title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Label(title, systemImage: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 8)
    }

    private var appearanceStrings: MenuBarAppearanceStrings {
        FeatureStrings.menuBarAppearance(l10n.language)
    }

    private var appearance: MenuBarMetricAppearance {
        MenuBarMetricAppearance(rawValue: Defaults.sanitizedMenuBarMetricAppearance(metricAppearance)) ?? .values
    }

    /// The readings that can sit in the menu bar, as tiles in the order they
    /// appear there.
    private var menuBarCard: some View {
        SettingsCard {
            MenuBarMetricTiles()
            Text(FeatureStrings.notchEditor(l10n.language).reorderHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var menuBarStyleCard: some View {
        SettingsCard(title: appearanceStrings.label) {
            HStack(spacing: 10) {
                MenuBarStyleChoice(appearance: .values, title: appearanceStrings.values,
                                   selected: appearance == .values) { metricAppearance = "values" }
                MenuBarStyleChoice(appearance: .bars, title: appearanceStrings.bars,
                                   selected: appearance == .bars) { metricAppearance = "bars" }
            }
            if appearance == .bars {
                MenuBarUsageBarSettings(strings: appearanceStrings)
            } else {
                SettingsRow(symbol: "thermometer.medium", title: l10n.s.monitorCombineTemperatures,
                            caption: l10n.s.monitorCombineTemperaturesCaption) {
                    Toggle(l10n.s.monitorCombineTemperatures, isOn: $combineTemperatures).labelsHidden()
                }
            }
            Divider()
            SettingsRow(symbol: "arrow.left.and.right", title: l10n.s.menuBarSpacingLabel) {
                Picker(l10n.s.menuBarSpacingLabel, selection: $metricSpacing) {
                    Text(l10n.s.menuBarSpacingStandard).tag("standard")
                    Text(l10n.s.menuBarSpacingCompact).tag("compact")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            SettingsRow(symbol: "eye.slash", title: l10n.s.menuBarHideIconToggle,
                        caption: l10n.s.menuBarHideIconCaption) {
                Toggle(l10n.s.menuBarHideIconToggle, isOn: $hideIconWithMetrics).labelsHidden()
            }
            SettingsRow(symbol: "rectangle.split.3x1", title: l10n.s.monitorSeparateMenuBarMetrics,
                        caption: appearance.allowsCombinedTemperatures
                            ? l10n.s.monitorSeparateMenuBarMetricsCaption : nil) {
                Toggle(l10n.s.monitorSeparateMenuBarMetrics, isOn: $separateMetrics).labelsHidden()
            }
        }
    }

    private var readingsCard: some View {
        SettingsCard {
            SettingsRow(symbol: "timer", title: l10n.s.monitorIntervalLabel) {
                HStack(spacing: 6) {
                    intervalChip(1, title: l10n.s.monitorInterval1)
                    intervalChip(2, title: l10n.s.monitorInterval2)
                    intervalChip(5, title: l10n.s.monitorInterval5)
                }
            }
            SettingsRow(symbol: "thermometer.medium", title: l10n.s.temperatures) {
                Picker(l10n.s.temperatures, selection: $temperatureUnit) {
                    Text("°C").tag(TemperatureUnit.celsius.rawValue)
                    Text("°F").tag(TemperatureUnit.fahrenheit.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if AppFeature.monitorNetwork.isAvailable {
                let title = FeatureStrings.monitorLayout(l10n.language).networkSpeedUnit
                SettingsRow(symbol: "network", title: title) {
                    Picker(title, selection: $networkSpeedUnit) {
                        Text("MB/s").tag(NetworkSpeedUnit.bytes)
                        Text("Mbps").tag(NetworkSpeedUnit.bits)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            if AppFeature.monitorMemory.isAvailable {
                SettingsRow(symbol: "memorychip", title: l10n.s.monitorMemoryMetricLabel) {
                    Picker(l10n.s.monitorMemoryMetricLabel, selection: $memoryMetric) {
                        Text(l10n.s.memoryMetricUsed).tag("used")
                        Text(l10n.s.memoryMetricApp).tag("app")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    private func intervalChip(_ seconds: Int, title: String) -> some View {
        let selected = interval == seconds
        return Button {
            interval = seconds
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .padding(.horizontal, 10)
                .frame(height: 26)
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

    private var alertsCard: some View {
        SettingsCard(title: FeatureStrings.monitorAlerts(l10n.language).section) {
            MonitorAlertsControls(compact: false)
        }
    }

    private var panelCard: some View {
        SettingsCard {
            MonitorPanelConfig()
            SettingsRow(symbol: "arrow.up.to.line", title: GraphScaleStrings.localized(l10n.language).title) {
                Toggle(GraphScaleStrings.localized(l10n.language).title, isOn: $graphScale).labelsHidden()
            }
        }
    }

    private var fanControlCard: some View {
        let fanStrings = FeatureStrings.fanControl(l10n.language)
        return SettingsCard {
            SettingsRow(symbol: "fanblades.fill", title: fanStrings.title, badge: l10n.s.betaBadge,
                        caption: fanStrings.settingsCaption) {
                Toggle(fanStrings.title, isOn: $showFanControl)
                    .labelsHidden()
                    .onChange(of: showFanControl) { _, _ in
                        FeatureRuntime.shared.sync([.fanControl])
                    }
            }
            Text(l10n.s.betaFeatureWarning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, settingsRowTextInset)
        }
    }
}
