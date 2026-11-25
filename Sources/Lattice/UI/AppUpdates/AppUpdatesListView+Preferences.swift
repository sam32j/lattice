// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    /// Built from the same header, card and rows as the other App Manager
    /// tabs, so its switches and the notify row's reveal match them.
    var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppManagerSectionHeader(title: text.updatePreferences)
            SettingsCard {
                SettingsControlRow(title: text.frequencyLabel) { schedulePicker }
                // The page's settingsExpansionAnimation, keyed on the same
                // condition, grows the card and moves the sections below.
                if showsNotifyRow {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                        SettingsControlRow(title: text.notifyToggle) {
                            Toggle(text.notifyToggle, isOn: notifyDisplayBinding)
                                .labelsHidden()
                                .disabled(isNotifyControlDisabled)
                                .opacity(isNotifyControlDisabled ? 0.45 : 1.0)
                        }
                        .padding(.top, SettingsCard<EmptyView>.headerSpacing)
                    }
                    .transition(.settingsReveal)
                }
                Divider()
                SettingsControlRow(title: text.excludedAppsTitle, caption: excludedSummaryText) {
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
            }
            .toggleStyle(.switch)
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
        .fixedSize()
        .disabled(isScheduleControlDisabled)
        .opacity(isScheduleControlDisabled ? 0.45 : 1.0)
        .onChange(of: frequencyRaw) { _, value in
            updates.syncWithPreferences()
            if AppUpdatesSupport.CheckFrequency.sanitized(value) != .off, notify {
                Notifier.requestPermission()
            }
        }
    }

    // MARK: - ALS (App List Sheet)

}
