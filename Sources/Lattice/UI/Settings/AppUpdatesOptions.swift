// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct AppUpdatesOptions: View {
    @ObservedObject private var updates = AppUpdatesService.shared
    @AppStorage(DefaultsKey.appUpdatesCheckFrequency)
    private var frequencyRaw = AppUpdatesSupport.CheckFrequency.off.rawValue
    @AppStorage(DefaultsKey.appUpdatesNotify) private var notify = true
    @AppStorage(DefaultsKey.appUpdatesIncludeHomebrewApps) private var includeHomebrewApps = true
    @AppStorage(DefaultsKey.appUpdatesIncludeAppStore) private var includeAppStore = true
    @AppStorage(DefaultsKey.appUpdatesIncludeOnlineCatalog)
    private var includeOnlineCatalog = true
    @State private var showingALS = false
    @State private var showingAppPicker = false

    private var currentFrequency: AppUpdatesSupport.CheckFrequency {
        AppUpdatesSupport.CheckFrequency.sanitized(frequencyRaw)
    }

    private var isScheduleOff: Bool {
        currentFrequency == .off
    }

    private var allSourcesOff: Bool {
        !includeHomebrewApps && !includeAppStore && !includeOnlineCatalog
    }

    private var isScheduleControlDisabled: Bool {
        allSourcesOff
    }

    private var isNotifyControlDisabled: Bool {
        isScheduleOff || allSourcesOff
    }

    private var excludedRules: [AppUpdatesSupport.UpdateRule] {
        updates.rules.filter { $0.version == nil }
    }

    private var excludedCount: Int {
        excludedRules.count
    }

    /// The notify preference is remembered even when it is shown as disabled.
    /// When checks are switched back on, it returns to its previous value.
    private var notifyDisplayBinding: Binding<Bool> {
        Binding {
            isNotifyControlDisabled ? false : notify
        } set: { newValue in
            guard !isNotifyControlDisabled else { return }
            notify = newValue
            if newValue {
                Notifier.requestPermission()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            updateChecksSection
            sourcesSection
        }
        .padding(14)
        .frame(width: 290)
        .fixedSize(horizontal: true, vertical: true)
        .sheet(isPresented: $showingALS) {
            alsSheet
        }
    }

    // MARK: - Section 1: Update checks

    private var updateChecksSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Update checks")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                // Schedule row
                scheduleControl
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, allSourcesOff ? 6 : 10)

                if allSourcesOff {
                    Text("Choose at least one source")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }

                divider

                // Notification row
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Notify me when updates are available")
                            .font(.system(size: 12))
                            .foregroundStyle(isNotifyControlDisabled ? Color.secondary : Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if isScheduleOff {
                            Text("Turn on update checks first")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 6)
                    Toggle("Notify me when updates are available", isOn: notifyDisplayBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(isNotifyControlDisabled)
                        .opacity(isNotifyControlDisabled ? 0.45 : 1.0)
                        .accessibilityLabel("Notify me when updates are available")
                        .accessibilityValue(notifyDisplayBinding.wrappedValue ? "On" : "Off")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                divider

                // Excluded Apps row
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Excluded Apps")
                            .font(.system(size: 12))
                        Text(excludedCount > 0 ? "\(excludedCount) \(excludedCount == 1 ? "app" : "apps") excluded" : "0 apps excluded")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        showingALS = true
                    } label: {
                        HStack(spacing: 3) {
                            Text("Manage")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manage excluded apps")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
    }

    private var scheduleControl: some View {
        HStack(spacing: 0) {
            segment(title: "Off", frequency: .off)
            segment(title: "Daily", frequency: .daily)
            segment(title: "Weekly", frequency: .weekly)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Check schedule")
        .accessibilityHint(allSourcesOff ? "Choose at least one source" : "")
        .disabled(isScheduleControlDisabled)
        .opacity(isScheduleControlDisabled ? 0.45 : 1.0)
    }

    private func segment(title: String, frequency: AppUpdatesSupport.CheckFrequency) -> some View {
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
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.accentColor)
                        : RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Section 2: Look for updates from

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Look for updates from")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                // Homebrew row
                HStack(alignment: .center, spacing: 8) {
                    Text("Homebrew")
                        .font(.system(size: 12))
                    Spacer(minLength: 8)
                    Toggle("Homebrew", isOn: $includeHomebrewApps)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("Homebrew")
                        .onChange(of: includeHomebrewApps) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                divider

                // App Store row
                HStack(alignment: .center, spacing: 8) {
                    Text("App Store")
                        .font(.system(size: 12))
                    Spacer(minLength: 8)
                    Toggle("App Store", isOn: $includeAppStore)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("App Store")
                        .onChange(of: includeAppStore) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                divider

                // Application Channel row
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Application Channel")
                            .font(.system(size: 12))
                        Text("Checks web-downloaded apps’ own update source")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Toggle("Application Channel", isOn: $includeOnlineCatalog)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("Application Channel")
                        .onChange(of: includeOnlineCatalog) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
    }

    private var alsSheet: some View {
        AppListSheet(
            caption: "Updates won’t be checked for these apps.",
            title: "Excluded Apps",
            centersContent: excludedRules.isEmpty,
            onDone: { showingALS = false }
        ) {
            if excludedRules.isEmpty {
                ContentUnavailableView("No Excluded Apps", systemImage: "app.dashed",
                                       description: Text("Apps you exclude from update checks will appear here."))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(excludedRules) { rule in
                        HStack(spacing: 9) {
                            Image(nsImage: InstalledApps.icon(for: rule.bundleID))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(rule.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Button {
                                updates.removeRule(rule)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove: \(rule.name)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(12)
            }
        } footer: {
            Button {
                showingAppPicker = true
            } label: {
                Label("Add App…", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            let listed = Set(excludedRules.map(\.bundleID))
            AppPickerView(canBrowseApplications: true, acceptsExecutables: false) {
                showingAppPicker = false
            } onSelect: { url in
                showingAppPicker = false
                updates.addExclusion(appAt: url)
            } onSelectApp: { app in
                showingAppPicker = false
                if let id = app.explicitIdentity ?? app.bundleID {
                    updates.storeRule(bundleID: id, name: app.name, version: nil)
                }
            } loadApps: {
                InstalledApps.installedBundleApplications(excluding: listed, includeRunningApplications: true)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

    private func handleSourceChange() {
        updates.sourceSelectionDidChange()
        updates.syncWithPreferences()
    }
}
