// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import SwiftUI

/// The uninstaller in the Hub and the island. It reuses AppUninstaller so the
/// scan and removal rules stay identical to the Settings tab, and fills the
/// space it is given: the app list first, then the scan, then the leftovers
/// with the button that removes them pinned under the list.
struct PanelUninstallerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var uninstaller = AppUninstaller.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @Environment(\.notchPresentation) private var inNotch
    @State private var query = ""
    @State private var apps: [InstalledApps.InstalledApp] = []
    @State private var loadingApps = false
    @State private var hoveredApp: URL?
    @State private var hoveredLeftover: UUID?
    @State private var pendingHomebrewRemoval: AppUninstaller.HomebrewRemovalConfirmation?
    @State private var showHomebrewDetails = false
    @FocusState private var searchFocused: Bool

    var onClose: () -> Void = {}

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // An app dropped on the panel is taken as chosen; there is no
            // zone for it here, the island offers one while dragging.
            .dropDestination(for: URL.self) { urls, _ in
                selectFirstApp(from: urls)
            }
            .onAppear {
                PanelInteractionState.shared.viewKeepsPopoverOpen = true
                uninstaller.clearRefusal()
            }
            .onDisappear {
                PanelInteractionState.shared.viewKeepsPopoverOpen = false
                dismissHomebrewRemovalConfirmation()
                uninstaller.clearRefusal()
            }
            .alert(l10n.s.homebrewConfirmUninstallTitle,
                   isPresented: homebrewRemovalConfirmationPresented,
                   presenting: pendingHomebrewRemoval) { confirmation in
                Button(l10n.s.uninstallerCancel, role: .cancel) {
                    dismissHomebrewRemovalConfirmation()
                }
                Button(l10n.s.homebrewUninstall, role: .destructive) {
                    uninstaller.removeSelectedWithHomebrew(confirmation: confirmation)
                    dismissHomebrewRemovalConfirmation()
                }
            } message: { confirmation in
                Text(String(format: l10n.s.homebrewConfirmUninstallBodyFormat, confirmation.package.displayName))
            }
    }

    @ViewBuilder
    private var content: some View {
        switch uninstaller.phase {
        case .empty: appChooser
        case .scanning: progress(l10n.s.uninstallerScanning, cancellable: true)
        case .results: results
        case .removing: progress(l10n.s.uninstallerRemoving, cancellable: false)
        case let .done(freed, failed): doneState(freed: freed, failed: failed)
        }
    }

    // MARK: Choosing an app

    private var appChooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField
            if let refusal = uninstaller.refusal {
                UninstallRefusalNote(refusal: refusal, compact: true)
            }
            appList
            if !permissions.fullDiskAccess {
                FullDiskAccessNote(compact: true)
            }
        }
        .onAppear {
            loadAppsIfNeeded()
            focusSearch()
        }
        // The island may open straight onto this list, by hovering too.
        .onReceive(NotchService.shared.$expanded.removeDuplicates().filter { $0 }) { _ in
            if inNotch { focusSearch() }
        }
    }

    /// Typing searches at once, with no click into the field first; in the
    /// island that means taking the keys, which hovering it open does not.
    /// Asked again for a moment: when the Hub or island opens straight onto
    /// this list, the page is still sliding in and the first ask is lost.
    private func focusSearch() {
        for delay in [0.0, 0.12, 0.3, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard uninstaller.phase == .empty, !searchFocused else { return }
                if inNotch { NotchService.shared.takeKeyboardFocus() }
                searchFocused = true
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(l10n.s.uninstallerPickerSearch, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFocused)
                .defaultFocus($searchFocused, true)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Color.primary.opacity(inNotch ? 0.1 : 0.06),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var filteredApps: [InstalledApps.InstalledApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || ($0.bundleID?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    @ViewBuilder
    private var appList: some View {
        let shown = filteredApps
        if loadingApps {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shown.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
                Text(l10n.s.uninstallerPickerEmpty)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Text(l10n.s.uninstallerPickerHiddenNote)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(shown) { app in
                        appRow(app)
                    }
                }
            }
            .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
            .hubScrollEdgeFade()
        }
    }

    private func appRow(_ app: InstalledApps.InstalledApp) -> some View {
        let hovered = hoveredApp == app.url
        return Button {
            selectApp(app.url)
        } label: {
            HStack(spacing: 9) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    let location = app.identity.flatMap(InstalledApps.location(for:))
                    Text(location ?? app.bundleID ?? app.url.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(location == nil ? .middle : .head)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(hovered ? 1 : 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(hovered ? (inNotch ? 0.12 : 0.07) : 0),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredApp = $0 ? app.url : (hoveredApp == app.url ? nil : hoveredApp) }
    }

    // MARK: Scanning and removing

    private func progress(_ message: String, cancellable: Bool) -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            if let target = uninstaller.target {
                Image(nsImage: target.icon)
                    .resizable()
                    .frame(width: 52, height: 52)
                Text(target.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if cancellable {
                Button(l10n.s.uninstallerCancel) { uninstaller.reset() }
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 6)
    }

    // MARK: Results

    private var results: some View {
        VStack(spacing: 0) {
            resultsHeader
                .padding(.bottom, 4)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(AppUninstaller.Category.allCases, id: \.self) { category in
                        let group = uninstaller.items.filter { $0.category == category }
                        if !group.isEmpty {
                            categorySection(group, category: category)
                        }
                    }
                }
            }
            // Each scan's list opens at its top, not where the last one was.
            .defaultScrollAnchor(.top)
            .id(uninstaller.target?.url)
            .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
            .hubScrollEdgeFade()
            homebrewStatus
            footer
                .padding(.top, 6)
        }
    }

    /// The app and what was found. The way back is Cancel beside the remove
    /// button: a back arrow here would sit right under the surface's own.
    private var resultsHeader: some View {
        HStack(spacing: 9) {
            if let target = uninstaller.target {
                Image(nsImage: target.icon)
                    .resizable()
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(target.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("\(Self.byteString(uninstaller.totalSize)) \(l10n.s.uninstallerFoundTitle)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func categorySection(_ group: [AppUninstaller.Leftover],
                                 category: AppUninstaller.Category) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label(for: category).uppercased())
                Spacer()
                Text(Self.byteString(group.reduce(0) { $0 + $1.size }))
                    .monospacedDigit()
            }
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(group.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, 34) }
                    leftoverRow(item)
                }
            }
            .background(Color.primary.opacity(inNotch ? 0.07 : 0.035),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    /// The whole row toggles; Show in Finder appears on hover.
    private func leftoverRow(_ item: AppUninstaller.Leftover) -> some View {
        let included = includeBinding(item)
        let hovered = hoveredLeftover == item.id
        return HStack(spacing: 8) {
            Toggle("", isOn: included)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .controlSize(.small)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 11.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if item.confidence == .related {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.orange)
                            .help(l10n.s.cleanerOptionalSection)
                            .accessibilityLabel(l10n.s.cleanerOptionalSection)
                    }
                }
                Text(prettyPath(item.url))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 4)
            if hovered {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l10n.s.cleanerRevealInFinder)
                .accessibilityLabel(l10n.s.cleanerRevealInFinder)
            }
            Text(Self.byteString(item.size))
                .font(.system(size: 10.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .opacity(included.wrappedValue ? 1 : 0.55)
        .contentShape(Rectangle())
        .onTapGesture { included.wrappedValue.toggle() }
        .onHover { hoveredLeftover = $0 ? item.id : (hoveredLeftover == item.id ? nil : hoveredLeftover) }
        .contextMenu {
            Button(l10n.s.cleanerRevealInFinder) {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: l10n.s.uninstallerSelectedFormat,
                            uninstaller.items.filter(\.include).count, uninstaller.items.count))
                    .font(.system(size: 11, weight: .medium))
                Text(Self.byteString(uninstaller.selectedSize))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(l10n.s.uninstallerCancel) { uninstaller.reset() }
                .disabled(uninstaller.isRemovingWithHomebrew)
            Button {
                if let confirmation = uninstaller.homebrewRemovalConfirmation {
                    presentHomebrewRemovalConfirmation(confirmation)
                } else {
                    uninstaller.removeSelected()
                }
            } label: {
                Label(removeButtonTitle, systemImage: "trash")
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!uninstaller.canRemoveSelected
                      || (uninstaller.selectedHomebrewPackage != nil && homebrew.isBusy))
        }
    }

    private var removeButtonTitle: String {
        uninstaller.selectedHomebrewPackage == nil ? l10n.s.uninstallerRemove : l10n.s.homebrewUninstall
    }

    @ViewBuilder
    private var homebrewStatus: some View {
        if uninstaller.homebrewCheckFailed {
            UninstallerHomebrewFailureNote(onRetry: uninstaller.retryHomebrewCheck)
                .padding(.top, 6)
        } else if let package = uninstaller.selectedHomebrewPackage {
            VStack(alignment: .leading, spacing: 6) {
                if let status = homebrew.operationStatus,
                   status.action == .uninstall,
                   status.package?.id == package.id {
                    HomebrewOperationStatusView(status: status,
                                                log: homebrew.log,
                                                terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                                compact: true,
                                                showDetails: $showHomebrewDetails,
                                                onCancel: homebrew.cancelOperation,
                                                onClear: homebrew.clearLog,
                                                onOpenTerminal: homebrew.openTerminalFallback)
                    if let tap = homebrew.untrustedTap {
                        HomebrewTrustCard(tap: tap, compact: true)
                    }
                    if let error = homebrew.errorMessage, !error.isEmpty {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Label(String(format: l10n.s.uninstallerHomebrewPackageFormat, package.displayName),
                          systemImage: "shippingbox")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Done

    private func doneState(freed: Int64, failed: [AppUninstaller.Leftover]) -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: UninstallerSupport.doneSymbol(hasLeftovers: !failed.isEmpty))
                .font(.system(size: 34))
                .foregroundStyle(failed.isEmpty ? .green : .orange)
            Text(l10n.s.uninstallerDoneTitle)
                .font(.system(size: 14, weight: .bold))
            Text(String(format: l10n.s.uninstallerFreedFormat, Self.byteString(freed)))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            if !failed.isEmpty {
                UninstallFailureNote(items: failed, compact: true)
            }
            Spacer(minLength: 0)
            Button(l10n.s.uninstallerAnother) {
                uninstaller.reset()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 6)
    }

    // MARK: Helpers

    private var homebrewRemovalConfirmationPresented: Binding<Bool> {
        Binding {
            pendingHomebrewRemoval != nil
        } set: { isPresented in
            if !isPresented { dismissHomebrewRemovalConfirmation() }
        }
    }

    private func presentHomebrewRemovalConfirmation(_ confirmation: AppUninstaller.HomebrewRemovalConfirmation) {
        // The alert would hang from the island as a sheet; there it asks on its own.
        guard !inNotch else {
            DispatchQueue.main.async {
                guard NSAlert.confirmAboveIsland(l10n.s.homebrewConfirmUninstallTitle,
                                                 message: String(format: l10n.s.homebrewConfirmUninstallBodyFormat,
                                                                 confirmation.package.displayName),
                                                 action: l10n.s.homebrewUninstall, destructive: true,
                                                 cancel: l10n.s.uninstallerCancel) else { return }
                uninstaller.removeSelectedWithHomebrew(confirmation: confirmation)
            }
            return
        }
        PanelInteractionState.shared.isPresentingPopoverModal = true
        pendingHomebrewRemoval = confirmation
    }

    private func dismissHomebrewRemovalConfirmation() {
        pendingHomebrewRemoval = nil
        PanelInteractionState.shared.isPresentingPopoverModal = false
    }

    private func includeBinding(_ item: AppUninstaller.Leftover) -> Binding<Bool> {
        Binding(
            get: { uninstaller.items.first(where: { $0.id == item.id })?.include ?? false },
            set: { uninstaller.setInclude($0, for: item.id) }
        )
    }

    private func selectApp(_ url: URL) {
        uninstaller.select(appURL: url)
    }

    private func selectFirstApp(from urls: [URL]) -> Bool {
        guard let app = urls.first(where: { $0.pathExtension == "app" }) ?? urls.first else {
            return false
        }
        return uninstaller.select(appURL: app)
    }

    private func loadAppsIfNeeded() {
        guard apps.isEmpty, !loadingApps else { return }
        loadingApps = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = UninstallerSupport.offeredApplications()
            DispatchQueue.main.async {
                apps = loaded
                loadingApps = false
            }
        }
    }

    private func prettyPath(_ url: URL) -> String {
        url.deletingLastPathComponent().path
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func label(for category: AppUninstaller.Category) -> String {
        switch category {
        case .app: return l10n.s.uninstallerCatApp
        case .support: return l10n.s.uninstallerCatSupport
        case .caches: return l10n.s.uninstallerCatCaches
        case .preferences: return l10n.s.uninstallerCatPreferences
        case .containers: return l10n.s.uninstallerCatContainers
        case .logs: return l10n.s.uninstallerCatLogs
        case .state: return l10n.s.uninstallerCatState
        case .other: return l10n.s.uninstallerCatOther
        }
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
