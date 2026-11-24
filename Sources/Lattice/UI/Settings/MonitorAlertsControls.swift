// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import UserNotifications

/// The System Monitor alerts as rows: each reading with the limit it fires
/// at and its switch, then how soon the same alert may repeat. The card
/// around them carries the explanation under its title.
struct MonitorAlertsControls: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var l10n = L10n.shared
    @State private var notificationsDenied = false
    @AppStorage(DefaultsKey.monitorAlertCPU) private var alertCPU = false
    @AppStorage(DefaultsKey.monitorAlertCPUTemperature) private var alertCPUTemperature = false
    @AppStorage(DefaultsKey.monitorAlertBatteryTemperature) private var alertBatteryTemperature = false
    @AppStorage(DefaultsKey.monitorAlertMemory) private var alertMemory = false
    @AppStorage(DefaultsKey.monitorAlertDisk) private var alertDisk = false
    @AppStorage(DefaultsKey.monitorAlertBattery) private var alertBattery = false
    @AppStorage(DefaultsKey.monitorAlertCPUThreshold) private var alertCPUThreshold = 90
    @AppStorage(DefaultsKey.monitorAlertCPUTemperatureThreshold) private var alertCPUTemperatureThreshold = 90
    @AppStorage(DefaultsKey.monitorAlertBatteryTemperatureThreshold) private var alertBatteryTemperatureThreshold = 40
    @AppStorage(DefaultsKey.monitorAlertDiskFreePercent) private var alertDiskFreePercent = 10
    @AppStorage(DefaultsKey.monitorAlertBatteryPercent) private var alertBatteryPercent = 15
    @AppStorage(DefaultsKey.monitorAlertCooldownMinutes) private var alertCooldown = 15

    private var text: MonitorAlertFeatureStrings {
        FeatureStrings.monitorAlerts(l10n.language)
    }


    private func temperature(_ celsius: Int) -> String {
        MetricFormat.temperature(Double(celsius))
    }

    private func percent(_ value: Int) -> String { "\(value)%" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Above the list, under the caption: nothing above it changes
            // size, so it never has to move when an alert's limit unrolls.
            MonitorAlertsRepeatMenu()
                .padding(.bottom, 6)
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 0) {
                    if index > 0 { Divider() }
                    MonitorAlertRow(row: row, reduceMotion: reduceMotion)
                }
                .transition(.settingsReveal)
            }
            // Alerts silently cannot fire when macOS notifications are denied
            // for the app; without this line that state is invisible.
            if notificationsDenied, anyAlertEnabled {
                Text(text.notificationsDenied)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .transition(.settingsReveal)
            }
        }
        // Each alert's limit unrolls with the page's managed reveal, keyed in
        // MonitorSettings so the card and every row under it move together.
        .settingsExpansionAnimation(value: notificationsDenied)
        .onAppear {
            sanitizeAlertValues()
            refreshNotificationStatus()
        }
        .onChange(of: alertCPU) { _, _ in MonitorAlertService.shared.syncWithPreferences(); refreshNotificationStatus() }
        .onChange(of: alertCPUTemperature) { _, _ in MonitorAlertService.shared.syncWithPreferences(); refreshNotificationStatus() }
        .onChange(of: alertBatteryTemperature) { _, _ in MonitorAlertService.shared.syncWithPreferences(); refreshNotificationStatus() }
        .onChange(of: alertMemory) { _, _ in MonitorAlertService.shared.syncWithPreferences(); refreshNotificationStatus() }
        .onChange(of: alertDisk) { _, _ in MonitorAlertService.shared.syncWithPreferences(); refreshNotificationStatus() }
        .onChange(of: alertBattery) { _, _ in MonitorAlertService.shared.syncWithPreferences(); refreshNotificationStatus() }
        .onChange(of: alertCPUThreshold) { _, _ in sanitizeAlertValues() }
        .onChange(of: alertCPUTemperatureThreshold) { _, _ in sanitizeAlertValues() }
        .onChange(of: alertBatteryTemperatureThreshold) { _, _ in sanitizeAlertValues() }
        .onChange(of: alertDiskFreePercent) { _, _ in sanitizeAlertValues() }
        .onChange(of: alertBatteryPercent) { _, _ in sanitizeAlertValues() }
        .onChange(of: alertCooldown) { _, _ in sanitizeAlertValues() }
    }

    /// The alerts this Mac's modules can raise, in reading order.
    private var rows: [MonitorAlertRow.Model] {
        var rows: [MonitorAlertRow.Model] = []
        if AppFeature.monitorCPU.isAvailable {
            rows.append(.init(id: "cpu", symbol: "cpu", title: text.cpu, isOn: $alertCPU,
                              limit: .init(format: text.aboveFormat, value: $alertCPUThreshold,
                                           values: Array(stride(from: 50, through: 100, by: 5)), label: percent)))
            rows.append(.init(id: "cpuTemperature", symbol: "thermometer.medium", title: text.cpuTemperature,
                              isOn: $alertCPUTemperature,
                              limit: .init(format: text.aboveFormat, value: $alertCPUTemperatureThreshold,
                                           values: Array(stride(from: 70, through: 105, by: 5)), label: temperature)))
        }
        if AppFeature.monitorMemory.isAvailable {
            rows.append(.init(id: "memory", symbol: "memorychip", title: text.memory, isOn: $alertMemory, limit: nil))
        }
        if AppFeature.monitorDisk.isAvailable {
            rows.append(.init(id: "disk", symbol: "internaldrive", title: text.disk, isOn: $alertDisk,
                              limit: .init(format: text.belowFormat, value: $alertDiskFreePercent,
                                           values: Array(stride(from: 5, through: 30, by: 5)), label: percent)))
        }
        if AppFeature.monitorPower.isAvailable, PowerSampler.hasInternalBattery {
            rows.append(.init(id: "battery", symbol: "battery.25percent", title: text.battery, isOn: $alertBattery,
                              limit: .init(format: text.belowFormat, value: $alertBatteryPercent,
                                           values: Array(stride(from: 5, through: 50, by: 5)), label: percent)))
            rows.append(.init(id: "batteryTemperature", symbol: "thermometer.high", title: text.batteryTemperature,
                              isOn: $alertBatteryTemperature,
                              limit: .init(format: text.aboveFormat, value: $alertBatteryTemperatureThreshold,
                                           values: Array(stride(from: 30, through: 50, by: 5)), label: temperature)))
        }
        return rows
    }

    private var anyAlertEnabled: Bool {
        alertCPU || alertCPUTemperature || alertMemory || alertDisk
            || (PowerSampler.hasInternalBattery && (alertBatteryTemperature || alertBattery))
    }

    /// Checked slightly delayed so a just-fired authorization prompt has a
    /// chance to be answered before the warning appears.
    private func refreshNotificationStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    notificationsDenied = settings.authorizationStatus == .denied
                }
            }
        }
    }

    private func sanitizeAlertValues() {
        alertCPUThreshold = Defaults.sanitizedPercent(alertCPUThreshold, fallback: 90, range: 50...100)
        alertCPUTemperatureThreshold = Defaults.sanitizedPercent(alertCPUTemperatureThreshold, fallback: 90, range: 70...105)
        alertBatteryTemperatureThreshold = Defaults.sanitizedPercent(alertBatteryTemperatureThreshold,
                                                                     fallback: 40,
                                                                     range: 30...50)
        alertDiskFreePercent = Defaults.sanitizedPercent(alertDiskFreePercent, fallback: 10, range: 5...30)
        alertBatteryPercent = Defaults.sanitizedPercent(alertBatteryPercent, fallback: 15, range: 5...50)
        alertCooldown = Defaults.sanitizedMonitorAlertCooldown(alertCooldown)
    }
}

/// One alert: its name and its switch. Once it is on, the limit it fires at
/// shows under the name ("Above 65%"), with a short slider under the switch
/// to change it; an alert that is off shows neither.
struct MonitorAlertRow: View {
    struct Limit {
        let format: String
        let value: Binding<Int>
        let values: [Int]
        let label: (Int) -> String
    }

    struct Model {
        let id: String
        let symbol: String
        let title: String
        let isOn: Binding<Bool>
        let limit: Limit?
    }

    let row: Model
    let reduceMotion: Bool

    var body: some View {
        let limit = row.isOn.wrappedValue ? row.limit : nil
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(row.title)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Toggle(row.title, isOn: row.isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if let limit {
                HStack(spacing: 12) {
                    Text(String(format: limit.format, limit.label(limit.value.wrappedValue)))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    slider(limit)
                }
                .transition(.settingsReveal)
            }
        }
        .padding(.vertical, 7)
    }

    /// Short and without tick marks; it still lands on the limit's steps.
    private func slider(_ limit: Limit) -> some View {
        let lower = Double(limit.values.first ?? 0)
        let upper = Double(limit.values.last ?? 100)
        let step = limit.values.count > 1 ? Double(limit.values[1] - limit.values[0]) : 1
        return Slider(value: Binding(get: { Double(limit.value.wrappedValue) },
                                     set: { raw in
                                         let snapped = (raw / step).rounded() * step
                                         limit.value.wrappedValue = Int(min(max(snapped, lower), upper))
                                     }),
                      in: lower...upper) {
            Text(row.title)
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 180)
        .accessibilityValue(String(format: limit.format, limit.label(limit.value.wrappedValue)))
    }
}

/// How soon the same alert may come back, for every alert at once. It is a
/// small line in caption type under the card's caption, so it reads as a
/// note on all the alerts rather than one more of them.
struct MonitorAlertsRepeatMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.monitorAlertCooldownMinutes) private var alertCooldown = 15
    @AppStorage(DefaultsKey.monitorAlertCPU) private var alertCPU = false
    @AppStorage(DefaultsKey.monitorAlertCPUTemperature) private var alertCPUTemperature = false
    @AppStorage(DefaultsKey.monitorAlertBatteryTemperature) private var alertBatteryTemperature = false
    @AppStorage(DefaultsKey.monitorAlertMemory) private var alertMemory = false
    @AppStorage(DefaultsKey.monitorAlertDisk) private var alertDisk = false
    @AppStorage(DefaultsKey.monitorAlertBattery) private var alertBattery = false

    var body: some View {
        let text = FeatureStrings.monitorAlerts(l10n.language)
        HStack(spacing: 6) {
            Text(text.cooldown)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(text.cooldown, selection: $alertCooldown) {
                Text(text.cooldown2).tag(2)
                Text(text.cooldown5).tag(5)
                Text(text.cooldown15).tag(15)
                Text(text.cooldown30).tag(30)
                Text(text.cooldown60).tag(60)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
        .disabled(!(alertCPU || alertCPUTemperature || alertMemory || alertDisk
                    || (PowerSampler.hasInternalBattery && (alertBatteryTemperature || alertBattery))))
    }
}
