// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The app update list, shared by the Settings page and the menu bar panel so
/// both look and behave cleanly. `compact` shrinks it for the panel.
struct AppUpdatesListView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = AppUpdatesService.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @Environment(\.notchPresentation) private var inNotch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DefaultsKey.appUpdatesCheckFrequency)
    private var frequencyRaw = AppUpdatesSupport.CheckFrequency.off.rawValue
    @AppStorage(DefaultsKey.appUpdatesNotify) private var notify = true
    @AppStorage(DefaultsKey.appUpdatesIncludeHomebrewApps) private var includeHomebrewApps = true
    @AppStorage(DefaultsKey.appUpdatesIncludeAppStore)
    private var includeAppStore = true
    @AppStorage(DefaultsKey.appUpdatesIncludeOnlineCatalog)
    private var includeOnlineCatalog = true
    @State private var showingALS = false
    @State private var showingAppPicker = false
    @State private var showOperationDetails = false
    @State private var skeletonPulse = false
    var compact = false

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

    private var excludedSummaryText: String {
        "\(excludedCount) \(excludedCount == 1 ? "app" : "apps") excluded from update checks"
    }

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

    private var text: AppUpdateStrings { FeatureStrings.appUpdates(l10n.language) }
    /// The row menu holds both rule actions, so it is named for neither.
    private var moreOptions: String { FeatureStrings.mouseClickDebounce(l10n.language).moreOptions }
    private var isBusy: Bool { updates.isChecking || homebrew.operation != nil }
    private var storeCoverageIncomplete: Bool {
        includeAppStore && !updates.appStoreAvailable
    }
    private var coverageIncomplete: Bool {
        updates.hasCheckedThisSession
            && !updates.isChecking
            && (storeCoverageIncomplete || (includeOnlineCatalog && !updates.onlineCatalogAvailable))
    }
    private var versionsUncompared: Bool {
        updates.hasCheckedThisSession
            && !updates.isChecking
            && includeOnlineCatalog && !updates.uncomparableAppNames.isEmpty
    }
    /// An app named as not compared is not known to be current either.
    private var coveragePartial: Bool { coverageIncomplete || versionsUncompared }

    private var totalAppsCount: Int {
        if allSourcesOff { return 0 }
        if updates.totalAppsCount > 0 { return updates.totalAppsCount }
        let count = InstalledApps.installedApplications().count
        return count > 0 ? count : 48
    }

    // MARK: - Status text & detail

    private var statusHeadline: String {
        if allSourcesOff {
            return "No update sources selected"
        }
        if !AppFeature.appUpdates.isAvailable {
            return "Update checks are off"
        }
        if updates.isChecking {
            if updates.items.isEmpty {
                return "Checking for updates…"
            } else {
                let count = updates.items.count
                return "\(count) \(count == 1 ? "update" : "updates") found…"
            }
        }
        if let error = updates.lastError, !error.isEmpty {
            return "Couldn’t check for updates"
        }
        if !updates.items.isEmpty {
            let count = updates.items.count
            return "\(count) \(count == 1 ? "update" : "updates") available"
        }
        return "All apps are up to date"
    }

    private var statusDetail: String {
        if allSourcesOff {
            return "Turn on at least one source to check for updates"
        }
        if !AppFeature.appUpdates.isAvailable {
            return "Turn on update checks to scan automatically"
        }
        if updates.isChecking {
            let checked = max(1, updates.checkedAppsCount)
            return "Checked \(checked) of \(totalAppsCount) apps"
        }
        if let error = updates.lastError, !error.isEmpty {
            return "Check your connection and try again"
        }
        return "Checked \(lastCheckRelativeText) · \(totalAppsCount) apps"
    }

    private var lastCheckRelativeText: String {
        guard let last = updates.lastCheck else { return "just now" }
        let interval = Date().timeIntervalSince(last)
        if interval < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: last, relativeTo: Date())
    }

    var body: some View {
        if compact {
            compactBody
        } else {
            overhauledBody
        }
    }

    // MARK: - Overhauled Page Layout

    private var overhauledBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                statusCard

                updateSourcesSection

                preferencesSection

                availableUpdatesHeader

                if allSourcesOff {
                    noSourcesCard
                        .transition(reduceMotion ? .identity : .opacity)
                } else if updates.isChecking && updates.items.isEmpty {
                    skeletonSection
                        .transition(reduceMotion ? .identity : .opacity)
                } else if !updates.items.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(updates.items) { item in
                            row(item)
                                .transition(reduceMotion ? .identity : .opacity)
                        }
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: updates.items)
                } else {
                    if let error = updates.lastError, !error.isEmpty {
                        errorCard
                            .transition(reduceMotion ? .identity : .opacity)
                    } else {
                        caughtUpCard
                            .transition(reduceMotion ? .identity : .opacity)
                    }
                }

                if let status = homebrew.operationStatus {
                    HomebrewOperationStatusView(status: status,
                                                log: homebrew.log,
                                                terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                                compact: false,
                                                showDetails: $showOperationDetails,
                                                onCancel: homebrew.cancelOperation,
                                                onClear: homebrew.clearLog,
                                                onOpenTerminal: homebrew.openTerminalFallback)
                        .padding(.top, 6)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingALS) {
            alsSheet
        }
        .onChange(of: statusHeadline) { _, newHeadline in
            AccessibilityNotification.Announcement("\(newHeadline), \(statusDetail)").post()
        }
    }

    private var availableUpdatesHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Available Updates")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if !updates.items.isEmpty {
                Text("\(updates.items.count) \(updates.items.count == 1 ? "app" : "apps")")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            } else if updates.isChecking {
                Text("Checking…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            } else if !allSourcesOff && updates.hasCheckedThisSession {
                Text("0 apps")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }

    private var skeletonSection: some View {
        VStack(spacing: 8) {
            skeletonRow(titleWidth: 130, subtitleWidth: 90)
            skeletonRow(titleWidth: 100, subtitleWidth: 70)
            skeletonRow(titleWidth: 150, subtitleWidth: 110)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                skeletonPulse = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Checking for updates…")
    }

    private func skeletonRow(titleWidth: CGFloat, subtitleWidth: CGFloat) -> some View {
        let shimmerOpacity = skeletonPulse ? 0.08 : 0.04
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(shimmerOpacity))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(shimmerOpacity))
                    .frame(width: titleWidth, height: 12)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.primary.opacity(shimmerOpacity * 0.75))
                    .frame(width: subtitleWidth, height: 10)
            }

            Spacer(minLength: 8)

            Capsule()
                .fill(Color.primary.opacity(shimmerOpacity))
                .frame(width: 72, height: 24)

            Circle()
                .fill(Color.primary.opacity(shimmerOpacity * 0.7))
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }

    // Status Card
    private var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(statusHeadline)
                    .font(.system(size: 14, weight: .semibold))
                Text(statusDetail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(statusHeadline), \(statusDetail)")

            Spacer(minLength: 16)

            Button {
                updates.check()
            } label: {
                HStack(spacing: 5) {
                    if updates.isChecking {
                        if reduceMotion {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Checking…")
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Check now")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundStyle(updates.isChecking || !AppFeature.appUpdates.isAvailable || allSourcesOff ? Color.secondary.opacity(0.6) : Color.primary.opacity(0.85))
            }
            .buttonStyle(.plain)
            .disabled(updates.isChecking || !AppFeature.appUpdates.isAvailable || allSourcesOff)
            .accessibilityLabel(updates.isChecking ? "Checking for updates" : "Check now")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Update Sources

    private var updateSourcesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Update sources")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                // Homebrew row
                HStack(alignment: .center) {
                    Text("Homebrew")
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    Toggle("Homebrew", isOn: $includeHomebrewApps)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("Homebrew")
                        .onChange(of: includeHomebrewApps) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                preferenceDivider

                // App Store row
                HStack(alignment: .center) {
                    Text("App Store")
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    Toggle("App Store", isOn: $includeAppStore)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("App Store")
                        .onChange(of: includeAppStore) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                preferenceDivider

                // Application Channel row
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Application Channel")
                            .font(.system(size: 13, weight: .regular))
                        Text("Checks web-downloaded app's own update source")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Application Channel", isOn: $includeOnlineCatalog)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("Application Channel")
                        .onChange(of: includeOnlineCatalog) { _, _ in handleSourceChange() }
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

    private func handleSourceChange() {
        updates.sourceSelectionDidChange()
        updates.syncWithPreferences()
    }

    // MARK: - Update Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Update Preferences")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                // Row 1: Automatic checks
                HStack(alignment: .center) {
                    Text("Automatic checks")
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    scheduleSegmentControl
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                preferenceDivider

                // Row 2: Notify when updates are available
                HStack(alignment: .center) {
                    Text("Notify when updates are available")
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    Toggle("Notify when updates are available", isOn: notifyDisplayBinding)
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
                        Text("Excluded Apps")
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
                            Text("Manage")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manage excluded apps")
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

    private var scheduleSegmentControl: some View {
        HStack(spacing: 0) {
            scheduleSegment(title: "Off", frequency: .off)
            scheduleSegment(title: "Daily", frequency: .daily)
            scheduleSegment(title: "Weekly", frequency: .weekly)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
        .disabled(isScheduleControlDisabled)
        .opacity(isScheduleControlDisabled ? 0.45 : 1.0)
    }

    private func scheduleSegment(title: String, frequency: AppUpdatesSupport.CheckFrequency) -> some View {
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

    private var preferenceDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
    }

    // MARK: - ALS (App List Sheet)

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

    private var caughtUpCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.green)
            Text("All apps are up to date.")
                .font(.system(size: 13.5, weight: .semibold))
            Text("\(totalAppsCount) apps checked, none need an update.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }

    private var noSourcesCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.orange)
            Text("Select update source to check for updates")
                .font(.system(size: 13.5, weight: .semibold))
            Text("Turn on at least one source above to look for updates.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }

    private var errorCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("Couldn’t check for updates")
                .font(.system(size: 13.5, weight: .semibold))
            if let error = updates.lastError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Button("Retry") {
                updates.check()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }

    // MARK: - Row Implementation

    private func row(_ item: AppUpdatesSupport.Item) -> some View {
        let isInstalling = updates.installingItemIDs.contains(item.id)
        let isWebApp = item.source == .onlineCatalog
        let buttonLabel = isInstalling ? "Updating…" : (isWebApp ? "Open to update" : "Update")
        let accessibleActionName = isWebApp ? "Open to update \(item.name)" : "Update \(item.name)"

        return HStack(spacing: 12) {
            Image(nsImage: icon(for: item))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: compact ? 26 : 36, height: compact ? 26 : 36)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: compact ? 11.5 : 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.versionSummary)
                    .font(.system(size: compact ? 9.5 : 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            Button {
                updates.update(item)
            } label: {
                Text(buttonLabel)
                    .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 10 : 14)
                    .padding(.vertical, compact ? 3.5 : 5.5)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isInstalling || isBusy)
            .opacity((isInstalling || isBusy) ? 0.55 : 1.0)
            .accessibilityLabel(accessibleActionName)

            if !compact, item.bundleID != nil {
                Menu {
                    ruleActions(for: item)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .tint(.secondary)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(moreOptions)
                .accessibilityLabel("\(moreOptions): \(item.name)")
            }
        }
        .padding(.horizontal, compact ? 8 : 14)
        .padding(.vertical, compact ? 6 : 10)
        .frame(height: compact ? Self.compactRowHeight : nil)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(compact ? 0.035 : 0.04))
        )
        .contextMenu { ruleActions(for: item) }
    }

    private func sourceChip(for source: AppUpdatesSupport.Source) -> some View {
        let labelText: String
        switch source {
        case .onlineCatalog: labelText = "Web"
        case .packageManager: labelText = "Homebrew"
        case .appStore: labelText = "App Store"
        }
        return Text(labelText)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            )
    }

    @ViewBuilder
    private func ruleActions(for item: AppUpdatesSupport.Item) -> some View {
        if item.bundleID != nil {
            Button("Skip version \(item.latestVersion)") {
                updates.skipVersion(item)
            }
            .disabled(isBusy)
            Button("Don’t check updates for \(item.name)") {
                updates.excludeApp(item)
            }
            .disabled(isBusy)
        }
    }

    private func icon(for item: AppUpdatesSupport.Item) -> NSImage {
        guard let path = item.bundlePath, FileManager.default.fileExists(atPath: path) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    // MARK: - Compact Mode (for Menu Bar Panel)

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryRow
                .panelCard()

            if allSourcesOff {
                compactNoSourcesState
            } else if updates.items.isEmpty {
                compactEmptyState
            } else {
                compactList
            }
            if coverageIncomplete {
                incompleteCheck
                    .panelCard()
            }
            if versionsUncompared {
                uncomparableVersions
                    .panelCard()
            }
            if let status = homebrew.operationStatus {
                HomebrewOperationStatusView(status: status,
                                            log: homebrew.log,
                                            terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                            compact: true,
                                            showDetails: $showOperationDetails,
                                            onCancel: homebrew.cancelOperation,
                                            onClear: homebrew.clearLog,
                                            onOpenTerminal: homebrew.openTerminalFallback)
            }
            if let error = updates.lastError, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .panelCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(lastCheckLine)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                updates.check()
            } label: {
                if updates.isChecking {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text(text.checking)
                    }
                    .font(.system(size: 10.5, weight: .medium))
                } else {
                    Label(text.checkNow, systemImage: "arrow.clockwise")
                        .font(.system(size: 10.5, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isBusy || allSourcesOff)
        }
    }

    private var lastCheckLine: String {
        if allSourcesOff { return "No sources selected" }
        guard let last = updates.lastCheck else { return text.neverChecked }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return String(format: text.lastCheckFormat,
                      formatter.localizedString(for: last, relativeTo: Date()))
    }

    @ViewBuilder
    private var compactEmptyState: some View {
        if updates.isChecking {
            VStack(spacing: inNotch ? 3 : 6) {
                if reduceMotion {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: inNotch ? 15 : 20))
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(inNotch ? .mini : .small)
                }
                Text("Checking for updates…")
                    .font(.system(size: inNotch ? 11 : 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, inNotch ? 6 : 20)
        } else {
            VStack(spacing: inNotch ? 3 : 6) {
                Image(systemName: coveragePartial ? "info.circle" : "checkmark.circle.fill")
                    .font(.system(size: inNotch ? 18 : 24))
                    .foregroundStyle(coveragePartial ? Color.secondary : Color.green)
                Label(coveragePartial ? text.partialUpToDate : "No updates available",
                      systemImage: coveragePartial ? "info.circle" : "checkmark.circle.fill")
                    .labelStyle(.titleOnly)
                    .font(.system(size: inNotch ? 11.5 : 13, weight: .medium))
                    .foregroundStyle(.secondary)
                if !coveragePartial {
                    Text("All installed apps are up to date")
                        .font(.system(size: inNotch ? 9.5 : 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, inNotch ? 6 : 20)
        }
    }

    private var compactNoSourcesState: some View {
        VStack(spacing: inNotch ? 3 : 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: inNotch ? 16 : 22))
                .foregroundStyle(.orange)
            Text("Select update source to check for updates")
                .font(.system(size: inNotch ? 11 : 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, inNotch ? 6 : 20)
    }

    private var incompleteCheck: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(text.incompleteCheck, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.orange)
            if !updates.uncheckedAppNames.isEmpty {
                Text(updates.uncheckedAppNames.joined(separator: ", "))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(updates.uncheckedAppNames.joined(separator: ", "))
            }
            Text(text.onlineUnavailable)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if storeCoverageIncomplete {
                Button(text.openAppStore) { updates.openAppStoreUpdates() }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
            }
        }
    }

    private var uncomparableVersions: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(text.uncomparableVersions, systemImage: "info.circle")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            Text(updates.uncomparableAppNames.joined(separator: ", "))
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .help(updates.uncomparableAppNames.joined(separator: ", "))
            Text(text.uncomparableVersionsNote)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var compactRulesSection: some View {
        DisclosureGroup(text.rulesTitle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(text.rulesHint)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(action: chooseExceptionApp) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isBusy)
                    .help(text.addException)
                    .accessibilityLabel(text.addException)
                }
                if updates.rules.isEmpty {
                    EmptyView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(updates.rules) { rule in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rule.name).fontWeight(.medium).lineLimit(1)
                                        Text(rule.version.map { String(format: text.skippedVersionFormat, $0) }
                                             ?? text.excludedApp)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .help(rule.bundleID)
                                    Spacer(minLength: 0)
                                    Button(text.removeRule) { updates.removeRule(rule) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(isBusy)
                                        .accessibilityLabel("\(text.removeRule): \(rule.name)")
                                }
                                .frame(height: 48)
                            }
                        }
                    }
                    .frame(height: CGFloat(min(updates.rules.count, 3)) * 54)
                }
            }
            .padding(.top, 4)
        }
        .font(.system(size: 10.5))
    }

    private func chooseExceptionApp() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = text.addException
        guard !inNotch else {
            DispatchQueue.main.async {
                guard panel.runAboveIsland() == .OK, let url = panel.url else { return }
                updates.addExclusion(appAt: url)
            }
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        updates.addExclusion(appAt: url)
    }

    @ViewBuilder
    private var compactList: some View {
        let rows = LazyVStack(alignment: .leading, spacing: Self.compactRowSpacing) {
            ForEach(updates.items) { item in
                row(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        ScrollView { rows }
            .frame(height: Self.compactHeight(rowCount: updates.items.count))
    }

    private static let compactRowHeight: CGFloat = 40
    private static let compactRowSpacing: CGFloat = 5
    private static let compactVisibleRows = 4

    static func compactHeight(rowCount: Int) -> CGFloat {
        let visible = min(max(rowCount, 1), compactVisibleRows)
        return CGFloat(visible) * compactRowHeight
            + CGFloat(visible - 1) * compactRowSpacing
    }
}
