// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// System Monitor's Menu Bar subpage: which readings sit next to the icon,
/// in what order, and how they are drawn.
struct MonitorMenuBarSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    @AppStorage(DefaultsKey.menuBarSeparateMetrics) private var separateMetrics = false
    @AppStorage(DefaultsKey.menuBarMetricSpacing) private var metricSpacing = "standard"
    @AppStorage(DefaultsKey.menuBarMetricAppearance) private var metricAppearance = "values"

    private var appearanceStrings: MenuBarAppearanceStrings {
        FeatureStrings.menuBarAppearance(l10n.language)
    }

    private var appearance: MenuBarMetricAppearance {
        MenuBarMetricAppearance(rawValue: Defaults.sanitizedMenuBarMetricAppearance(metricAppearance)) ?? .values
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if MenuBarMetric.order(in: .standard).contains(where: { $0.feature.isAvailable && $0.isAvailableOnCurrentHardware }) {
                    readingsCard
                        .transition(.settingsReveal)
                }
                styleCard
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .onAppear { metricAppearance = Defaults.sanitizedMenuBarMetricAppearance(metricAppearance) }
        .settingsExpansionAnimation(value: metricAppearance)
        .settingsExpansionAnimation(value: FeatureVisibilitySupport.monitorFeatures.map(\.isAvailable))
    }

    private var strings: SystemMonitorSettingsStrings { FeatureStrings.systemMonitorSettings(l10n.language) }

    /// The readings that can sit in the menu bar, in the order they appear.
    private var readingsCard: some View {
        SettingsCard(title: strings.readingsTitle, caption: strings.readingsCaption) {
            MenuBarReadingsList()
        }
    }

    /// How the readings are drawn. Each row is one line; what a switch does
    /// beyond its title sits in its tooltip.
    private var styleCard: some View {
        SettingsCard(title: strings.styleTitle) {
            HStack(spacing: 10) {
                MenuBarStyleChoice(appearance: .values, title: appearanceStrings.values,
                                   selected: appearance == .values) { metricAppearance = "values" }
                MenuBarStyleChoice(appearance: .bars, title: appearanceStrings.bars,
                                   selected: appearance == .bars) { metricAppearance = "bars" }
            }
            // Bars take the System widget's colors and levels, so there is
            // nothing to set for them; combining usage and temperature is a
            // per-component switch in the readings list.
            SettingsControlRow(title: l10n.s.monitorSeparateMenuBarMetrics) {
                Toggle(l10n.s.monitorSeparateMenuBarMetrics, isOn: $separateMetrics).labelsHidden()
            }
            .help(appearance.allowsCombinedTemperatures ? l10n.s.monitorSeparateMenuBarMetricsCaption : "")
            SettingsControlRow(title: l10n.s.menuBarSpacingLabel) {
                Picker(l10n.s.menuBarSpacingLabel, selection: $metricSpacing) {
                    Text(l10n.s.menuBarSpacingStandard).tag("standard")
                    Text(l10n.s.menuBarSpacingCompact).tag("compact")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }
    }
}
