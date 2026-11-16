// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.updatePreferences)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                // Row 1: Automatic checks
                HStack(alignment: .center) {
                    Text(text.frequencyLabel)
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    schedulePicker
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                // The page's settingsExpansionAnimation, keyed on the same
                // condition, grows the card and moves the sections below.
                VStack(alignment: .leading, spacing: 0) {
                    preferenceDivider
                    HStack(alignment: .center) {
                        Text(text.notifyToggle)
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Toggle(text.notifyToggle, isOn: notifyDisplayBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .disabled(isNotifyControlDisabled)
                            .opacity(isNotifyControlDisabled ? 0.45 : 1.0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .settingsCollapsible(isExpanded: showsNotifyRow)

                preferenceDivider

                // Row 3: Excluded Apps
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text.excludedAppsTitle)
                            .font(.system(size: 13, weight: .regular))
                        Text(excludedSummaryText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingALS = true
                    } label: {
                        HStack(spacing: 3) {
                            Text(text.manage)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(text.manageExcludedApps)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }

    /// Native settings picker instead of a custom segmented control. The
    /// frequency has always supported all three modes at the service level.
    var schedulePicker: some View {
        Picker(text.frequencyLabel, selection: $frequencyRaw) {
            Text(text.frequencyOff).tag(AppUpdatesSupport.CheckFrequency.off.rawValue)
            Text(text.frequencyDaily).tag(AppUpdatesSupport.CheckFrequency.daily.rawValue)
            Text(text.frequencyWeekly).tag(AppUpdatesSupport.CheckFrequency.weekly.rawValue)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 140, alignment: .trailing)
        .disabled(isScheduleControlDisabled)
        .opacity(isScheduleControlDisabled ? 0.45 : 1.0)
        .onChange(of: frequencyRaw) { _, value in
            updates.syncWithPreferences()
            if AppUpdatesSupport.CheckFrequency.sanitized(value) != .off, notify {
                Notifier.requestPermission()
            }
        }
    }

    var preferenceDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
    }

    // MARK: - ALS (App List Sheet)

}
