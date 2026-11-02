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
    @AppStorage(DefaultsKey.appUpdatesIncludeOnlineCatalog)
    private var includeOnlineCatalog = true
    @AppStorage(DefaultsKey.appUpdatesIncludeAppStore)
    private var includeAppStore = true
    @State private var showOperationDetails = false
    var compact = false

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
        if updates.totalAppsCount > 0 { return updates.totalAppsCount }
        let count = InstalledApps.installedApplications().count
        return count > 0 ? count : 48
    }

    // MARK: - Status text & detail

    private var statusHeadline: String {
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
        VStack(alignment: .leading, spacing: 14) {
            statusCard

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    if !updates.items.isEmpty {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Available Updates")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(updates.items.count) \(updates.items.count == 1 ? "app" : "apps")")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)

                        LazyVStack(spacing: 8) {
                            ForEach(updates.items) { item in
                                row(item)
                                    .transition(reduceMotion ? .identity : .opacity)
                            }
                        }
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: updates.items)
                    } else if !updates.isChecking {
                        if let error = updates.lastError, !error.isEmpty {
                            errorCard
                                .transition(reduceMotion ? .identity : .opacity)
                        } else if updates.hasCheckedThisSession {
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
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: statusHeadline) { _, newHeadline in
            AccessibilityNotification.Announcement("\(newHeadline), \(statusDetail)").post()
        }
    }

    // Status Card
    private var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(statusHeadline)
                    .font(.system(size: 13, weight: .semibold))
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
                                .font(.system(size: 10))
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Checking")
                            .font(.system(size: 11.5, weight: .medium))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Check now")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                }
                .frame(width: 100, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(updates.isChecking || !AppFeature.appUpdates.isAvailable)
            .accessibilityLabel(updates.isChecking ? "Checking for updates" : "Check now")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
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
        .padding(.vertical, 32)
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

        return HStack(spacing: 10) {
            Image(nsImage: icon(for: item))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: compact ? 26 : 36, height: compact ? 26 : 36)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    sourceChip(for: item.source)
                }
                Text(item.versionSummary)
                    .font(.system(size: compact ? 9.5 : 10.5))
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
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
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .frame(height: compact ? Self.compactRowHeight : 50)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(compact ? 0.035 : 0.035))
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
            if updates.items.isEmpty {
                compactEmptyState
            } else {
                compactList
            }
            compactRulesSection
            if coverageIncomplete {
                incompleteCheck
            }
            if versionsUncompared {
                uncomparableVersions
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
            .disabled(isBusy)
        }
    }

    private var lastCheckLine: String {
        guard let last = updates.lastCheck else { return text.neverChecked }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return String(format: text.lastCheckFormat,
                      formatter.localizedString(for: last, relativeTo: Date()))
    }

    @ViewBuilder
    private var compactEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            if updates.hasCheckedThisSession, !updates.isChecking {
                Label(coveragePartial ? text.partialUpToDate
                      : (updates.rules.isEmpty ? text.upToDate : text.noVisibleUpdates),
                      systemImage: coveragePartial || !updates.rules.isEmpty
                          ? "info.circle" : "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(coveragePartial || !updates.rules.isEmpty
                                     ? Color.secondary : Color.green)
            }
            Text(text.coverageNote)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if updates.hasCheckedThisSession, !updates.packageManagerAvailable {
                Text(text.packageMissing)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
