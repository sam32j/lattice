// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The App Manager's App Uninstaller tab: browse the installed apps (or drop
/// one), review what an app leaves behind by category, remove it with a
/// footer docked under the list, then see what was freed.
struct AppUninstallerTab: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var uninstaller = AppUninstaller.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var catalog = AppUninstallerCatalog.shared
    @State private var query = ""
    @State private var scope = AppUninstallerCatalog.Scope.all
    @State private var armed = false
    @State private var armReset: DispatchWorkItem?
    @State private var summary: AppUninstallSummary?
    @State private var showHomebrewDetails = false

    private var strings: AppUninstallerTabStrings { FeatureStrings.appUninstallerTab(l10n.language) }
    private var s: Strings { l10n.s }

    var body: some View {
        content
            .onAppear {
                uninstaller.clearRefusal()
                catalog.load()
                syncInspection(uninstaller.phase)
            }
            .onDisappear { uninstaller.clearRefusal() }
            .onChange(of: uninstaller.phase) { _, phase in
                armed = false
                if phase == .empty { catalog.load(force: summary != nil); summary = nil }
                syncInspection(phase)
            }
    }

    private static let inspectionSubpage = "appUninstaller.inspect"

    /// An app being inspected is a step of the Settings window's history:
    /// Back returns to the app list, and leaving the page closes it.
    private func syncInspection(_ phase: AppUninstaller.Phase) {
        let router = SettingsRouter.shared
        if phase == .empty {
            router.endSubpage(Self.inspectionSubpage)
        } else {
            router.pushSubpage(Self.inspectionSubpage) {
                // A removal under way finishes; anything else closes.
                if AppUninstaller.shared.phase != .removing { AppUninstaller.shared.reset() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch uninstaller.phase {
        case .empty: browse
        case .scanning: busy(strings.scanningTitle, cancellable: true)
        case .results: results
        case .removing:
            busy(String(format: uninstaller.selectedHomebrewPackage == nil ? strings.trashingFormat
                            : strings.uninstallingFormat, uninstaller.target?.name ?? ""), cancellable: false)
        case let .done(freed, failed): done(freed: freed, failed: failed)
        }
    }

    // MARK: Browse

    private var browse: some View {
        AppManagerPage {
            AppManagerDropStrip(symbol: "trash", tint: .red, headline: strings.dropTitle,
                                detail: strings.dropDetail, types: [.fileURL],
                                onDrop: { urls in
                                    if let app = urls.first(where: { $0.pathExtension == "app" }) ?? urls.first {
                                        uninstaller.select(appURL: app)
                                    }
                                }) {
                Button(strings.uninstallButton, action: choose)
                    .buttonStyle(.appManager())
            }
            if let refusal = uninstaller.refusal {
                UninstallRefusalNote(refusal: refusal)
            }
            if !permissions.fullDiskAccess {
                AppManagerBanner(title: strings.fdaTitle, detail: strings.fdaDetail) {
                    Button(strings.grantAccess) { Permissions.shared.requestFullDiskAccess() }
                        .buttonStyle(.appManager())
                }
            }
            // On its own, so it sits as far above the heading as Homebrew's.
            searchBar
            VStack(alignment: .leading, spacing: 8) {
                let apps = catalog.filtered(query: query, scope: scope)
                AppManagerSectionHeader(title: strings.applicationsTitle,
                                        meta: String(format: strings.appCountFormat, apps.count)) {
                    // Only once sizes have come in; none read yet is not zero.
                    let sizes = apps.compactMap(\.size)
                    if !sizes.isEmpty {
                        Text(AppManagerFormat.bytes(sizes.reduce(0, +)))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                SettingsCard {
                    if catalog.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(strings.loadingApps).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    } else if apps.isEmpty {
                        Text(String(format: strings.noMatchesFormat, query))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                                if index > 0 { Divider().padding(.leading, 40).padding(.vertical, 6) }
                                appRow(app)
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        AppManagerSearchField(placeholder: strings.filterPlaceholder, text: $query) {
            Menu {
                Picker(strings.scopeAll, selection: $scope) {
                    Text(strings.scopeAll).tag(AppUninstallerCatalog.Scope.all)
                    Text(strings.scopeLargest).tag(AppUninstallerCatalog.Scope.largest)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                SearchFilterMenuLabel(title: scope == .largest ? strings.scopeLargest : strings.scopeAll)
            }
            .menuStyle(.button)
        .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func appRow(_ app: AppUninstallerCatalog.Entry) -> some View {
        Button {
            uninstaller.select(appURL: app.url)
        } label: {
            HStack(spacing: 12) {
                AppManagerAppIcon(path: app.url.path, name: app.name)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        if app.cask != nil { AppManagerChip(text: strings.scopeHomebrew, tone: .purple) }
                        if app.running { AppManagerChip(text: strings.running, tone: .accent) }
                    }
                    Text([app.size.map(AppManagerFormat.bytes), app.version.map { "v\($0)" }]
                            .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                Text(strings.inspect)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5.5)
                    .background(Color.primary.opacity(0.1), in: Capsule())
                    .foregroundStyle(Color.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        uninstaller.select(appURL: url)
    }

    // MARK: Busy

    private func busy(_ message: String, cancellable: Bool) -> some View {
        AppManagerPage {
            AppManagerStatusCard(leading: {
                if let target = uninstaller.target {
                    Image(nsImage: target.icon).resizable().frame(width: 40, height: 40)
                }
            }, headline: message, detail: uninstaller.target?.bundleID ?? uninstaller.target?.url.path) {
                if cancellable {
                    Button(s.uninstallerCancel) { uninstaller.reset() }
                        .buttonStyle(.appManager(.neutral))
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            // Shaped like what the scan brings back: a category heading
            // over a card of leftover rows, and the footer that holds the
            // remove button.
            UninstallerLeftoverSkeleton()
        } footer: {
            AppManagerDockedFooter {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).frame(width: 110, height: 10)
                    RoundedRectangle(cornerRadius: 3).frame(width: 150, height: 8)
                }
                Spacer()
                Capsule().frame(width: 96, height: 26)
            }
            .foregroundStyle(Color.primary.opacity(0.08))
            .accessibilityHidden(true)
        }
    }

    // MARK: Results

    private var results: some View {
        AppManagerPage {
            if let target = uninstaller.target {
                AppManagerStatusCard(leading: {
                    Image(nsImage: target.icon).resizable().frame(width: 40, height: 40)
                }, headline: target.name,
                   detail: [target.bundleID, String(format: strings.foundFormat,
                                                     AppManagerFormat.bytes(uninstaller.totalSize))]
                    .compactMap { $0 }.joined(separator: " · ")) {
                    // The way back sits with the app it is about, as while scanning.
                    Button(s.uninstallerCancel) { uninstaller.reset() }
                        .buttonStyle(.appManager(.neutral))
                        .disabled(uninstaller.isRemovingWithHomebrew)
                }
            }
            homebrewNotice
            ForEach(AppUninstaller.Category.allCases, id: \.self) { category in
                let group = uninstaller.items.filter { $0.category == category }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        AppManagerSectionHeader(title: label(for: category)) {
                            Text(AppManagerFormat.bytes(group.map(\.size).reduce(0, +)))
                                .font(.system(size: 11.5)).foregroundStyle(.secondary).monospacedDigit()
                        }
                        SettingsCard {
                            ForEach(Array(group.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Divider() }
                                leftoverRow(item)
                            }
                        }
                    }
                }
            }
        } footer: {
            resultsFooter
        }
    }

    @ViewBuilder
    private var homebrewNotice: some View {
        if uninstaller.homebrewCheckFailed {
            UninstallerHomebrewFailureNote(onRetry: uninstaller.retryHomebrewCheck)
        } else if let package = uninstaller.selectedHomebrewPackage {
            if let status = homebrew.operationStatus, status.action == .uninstall, status.package?.id == package.id {
                HomebrewOperationStatusView(status: status, log: homebrew.log,
                                            terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                            compact: false, showDetails: $showHomebrewDetails,
                                            onCancel: homebrew.cancelOperation, onClear: homebrew.clearLog,
                                            onOpenTerminal: homebrew.openTerminalFallback)
                if let tap = homebrew.untrustedTap { HomebrewTrustCard(tap: tap) }
            } else {
                AppManagerBanner(title: strings.managedTitle,
                                 detail: String(format: strings.managedFormat, "brew uninstall --cask \(package.name)"),
                                 info: true) {
                    AppManagerChip(text: package.name, tone: .purple)
                }
            }
        }
    }

    private func leftoverRow(_ item: AppUninstaller.Leftover) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { uninstaller.items.first(where: { $0.id == item.id })?.include ?? false },
                                     set: { uninstaller.setInclude($0, for: item.id); armed = false }))
                .labelsHidden()
                .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.system(size: 12.5)).lineLimit(1).truncationMode(.middle)
                    if item.confidence == .related { AppManagerChip(text: s.cleanerOptionalSection, tone: .orange) }
                }
                Text(item.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 8)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: { Image(systemName: "folder") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(s.cleanerRevealInFinder)
                .accessibilityLabel(s.cleanerRevealInFinder)
            Text(AppManagerFormat.bytes(item.size))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 56, alignment: .trailing)
        }
    }

    private var resultsFooter: some View {
        AppManagerDockedFooter {
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: s.uninstallerSelectedFormat,
                            uninstaller.items.filter(\.include).count, uninstaller.items.count))
                    .font(.system(size: 12.5, weight: .semibold))
                Text(String(format: strings.recoverFormat, AppManagerFormat.bytes(uninstaller.selectedSize)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button(armed ? strings.confirmRemoval
                   : (uninstaller.selectedHomebrewPackage == nil ? s.uninstallerRemove : strings.uninstallViaHomebrew)) {
                remove()
            }
            .buttonStyle(.appManager(.destructive))
            .disabled(!uninstaller.canRemoveSelected
                      || (uninstaller.selectedHomebrewPackage != nil && homebrew.isBusy))
        }
    }

    /// The first click arms the button; a second within a few seconds removes.
    private func remove() {
        guard armed else {
            armed = true
            armReset?.cancel()
            let reset = DispatchWorkItem { armed = false }
            armReset = reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: reset)
            return
        }
        armReset?.cancel()
        armed = false
        summary = AppUninstallSummary(uninstaller: uninstaller)
        if let confirmation = uninstaller.homebrewRemovalConfirmation {
            uninstaller.removeSelectedWithHomebrew(confirmation: confirmation)
        } else {
            uninstaller.removeSelected()
        }
    }

    // MARK: Done

    private func done(freed: Int64, failed: [AppUninstaller.Leftover]) -> some View {
        let blockedByAccess = !failed.isEmpty
            && UninstallerSupport.failureNeedsFullDiskAccess(paths: failed.map(\.url.path))
        let cleaned = max(0, (summary?.count ?? 0) - failed.count)
        return VStack(spacing: 18) {
            Spacer(minLength: 12)
            ZStack(alignment: .bottomTrailing) {
                if let icon = summary?.icon {
                    Image(nsImage: icon).resizable().frame(width: 64, height: 64)
                } else {
                    Image(systemName: "app.dashed").font(.system(size: 52)).foregroundStyle(.secondary)
                }
                Image(systemName: UninstallerSupport.doneSymbol(hasLeftovers: !failed.isEmpty))
                    .font(.system(size: 22))
                    .foregroundStyle(.white, failed.isEmpty ? Color.green : Color.orange)
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-2))
                    .offset(x: 6, y: 6)
            }
            VStack(spacing: 4) {
                Text(String(format: strings.uninstalledFormat, summary?.name ?? uninstaller.target?.name ?? ""))
                    .font(.system(size: 18, weight: .bold))
                Text(summary?.cask.map { String(format: strings.doneHomebrewFormat, $0) } ?? strings.doneTrash)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 0) {
                metric(AppManagerFormat.bytes(freed), strings.spaceFreed, tint: .green)
                Divider().frame(height: 34)
                metric(String(format: strings.itemsFormat, cleaned), strings.cleaned)
                Divider().frame(height: 34)
                metric(summary?.cask == nil ? strings.trash : s.homebrewName, strings.method)
            }
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: 440)
            if blockedByAccess {
                AppManagerBanner(title: String(format: strings.skippedFormat, failed.count),
                                 detail: strings.skippedDetail) {
                    Button(strings.grant) { Permissions.shared.requestFullDiskAccess() }
                        .buttonStyle(.appManager())
                }
                .frame(maxWidth: 440)
            } else if !failed.isEmpty {
                UninstallFailureNote(items: failed).frame(maxWidth: 440)
            } else if let breakdown = summary?.breakdown, !breakdown.isEmpty {
                VStack(spacing: 6) {
                    ForEach(breakdown.prefix(4), id: \.category) { row in
                        HStack {
                            Text(label(for: row.category)).foregroundStyle(.secondary)
                            Spacer()
                            Text(AppManagerFormat.bytes(row.size)).monospacedDigit()
                        }
                        .font(.system(size: 12))
                    }
                }
                .frame(maxWidth: 440)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Button(strings.openTrash) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash"))
                }
                .buttonStyle(.appManager(.neutral))
                Button(strings.done) { uninstaller.reset() }
                    .buttonStyle(.appManager())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metric(_ value: String, _ label: String, tint: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(tint ?? .primary)
                .monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func label(for category: AppUninstaller.Category) -> String {
        switch category {
        case .app: return s.uninstallerCatApp
        case .support: return s.uninstallerCatSupport
        case .caches: return s.uninstallerCatCaches
        case .preferences: return s.uninstallerCatPreferences
        case .containers: return s.uninstallerCatContainers
        case .logs: return s.uninstallerCatLogs
        case .state: return s.uninstallerCatState
        case .other: return s.uninstallerCatOther
        }
    }
}

/// What a removal was about, taken as it starts: the done screen still names
/// the app and breaks down what went once the uninstaller has moved on.
struct AppUninstallSummary {
    struct Row { let category: AppUninstaller.Category; let size: Int64 }

    let name: String
    let icon: NSImage?
    let count: Int
    let cask: String?
    let breakdown: [Row]

    @MainActor
    init(uninstaller: AppUninstaller) {
        let selected = uninstaller.items.filter(\.include)
        name = uninstaller.target?.name ?? ""
        icon = uninstaller.target?.icon
        count = selected.count
        cask = uninstaller.selectedHomebrewPackage?.name
        breakdown = Dictionary(grouping: selected, by: \.category)
            .map { Row(category: $0.key, size: $0.value.map(\.size).reduce(0, +)) }
            .sorted { $0.size > $1.size }
    }
}

/// A placeholder in the shape of the leftovers a scan finds: a category
/// heading and its size over a card of rows with a checkbox, a name, a
/// path and a size.
struct UninstallerLeftoverSkeleton: View {
    var rows = 4
    @State private var dim = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 3).frame(width: 90, height: 9)
                Spacer()
                RoundedRectangle(cornerRadius: 3).frame(width: 48, height: 9)
            }
            .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 13) {
                ForEach(0..<rows, id: \.self) { index in
                    if index > 0 { Rectangle().frame(height: 1).opacity(0.5) }
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3).frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).frame(width: [150, 110, 180, 130][index % 4], height: 10)
                            RoundedRectangle(cornerRadius: 3).frame(width: [220, 190, 240, 170][index % 4], height: 8)
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 3).frame(width: 52, height: 9)
                    }
                }
            }
            .padding(16)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .foregroundStyle(Color.primary.opacity(dim ? 0.05 : 0.1))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { dim = true }
        }
        .accessibilityHidden(true)
    }
}
