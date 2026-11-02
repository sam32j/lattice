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
                    scheduleSegmentControl
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                preferenceDivider

                // Row 2: Notify when updates are available
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

    var scheduleSegmentControl: some View {
        HStack(spacing: 0) {
            scheduleSegment(title: text.frequencyOff, frequency: .off)
            scheduleSegment(title: text.frequencyDaily, frequency: .daily)
            scheduleSegment(title: text.frequencyWeekly, frequency: .weekly)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
        .disabled(isScheduleControlDisabled)
        .opacity(isScheduleControlDisabled ? 0.45 : 1.0)
    }

    func scheduleSegment(title: String, frequency: AppUpdatesSupport.CheckFrequency) -> some View {
        let isSelected = currentFrequency == frequency
        return Button {
            guard !isScheduleControlDisabled else { return }
            frequencyRaw = frequency.rawValue
            updates.syncWithPreferences()
            if frequency != .off, notify {
                Notifier.requestPermission()
            }
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.accentColor)
                        : RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var preferenceDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
    }

    // MARK: - ALS (App List Sheet)

}
