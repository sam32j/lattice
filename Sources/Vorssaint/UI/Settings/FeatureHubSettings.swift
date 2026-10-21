// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import AppKit

/// Preserves scroll position and the last opened feature across Settings navigation.
@MainActor
final class FeatureHubNavigationState: ObservableObject {
    static let shared = FeatureHubNavigationState()
    var scrollOffset: CGFloat = 0
    var lastNavigatedFeature: AppFeature?
}

/// The Features hub. Install or uninstall each feature, grouped in plain
/// language: uninstalling removes it from the whole app (Settings, panel,
/// menu bar, shortcuts) and stops its work; its configuration is kept for
/// its return. Permission management lives in Data and Permissions.
struct FeatureHubSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var router = SettingsRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Tracks the feature-target request currently being revealed, so a
    /// delayed retry from an older request cannot act after a newer one has
    /// already taken over (same convention as `SettingsSectionFocusModifier`).
    @State private var revealID = UUID()
    /// The row briefly tinted after a search or Command Bar selection lands
    /// on it, mirroring the section highlight `SettingsSectionFocusModifier`
    /// gives an ordinary page anchor.
    @State private var highlightedFeature: AppFeature?
    @State private var expandedGroups = Set(FeatureGroup.allCases)
    @State private var islandExtensionsExpanded = true
    /// Installed switches never once turned on, read when the page appears
    /// and after every install change rather than on every redraw.
    @State private var neverUsed: [AppFeature] = []
    /// The batch just uninstalled from that card, kept for its Undo.
    @State private var recentlyUninstalled: [AppFeature] = []

    /// Below this, the offer would be more to read than it saves.
    private static let neverUsedMinimum = 3


    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onAppear {
                    refreshNeverUsed()
                    revealPendingFeatureTarget(using: proxy)
                }
                .onChange(of: router.requestID) { _, _ in revealPendingFeatureTarget(using: proxy) }
                .onChange(of: features.revision) { _, _ in refreshNeverUsed() }
        }
    }
    private var content: some View {
        // The lazy stack has to be the scroll view's own content (issue
        // #2270). Nested in a plain stack, it resized that stack each time a
        // card came into view: scrolling stalled for up to a second, and the
        // layout could keep redoing itself until Settings froze.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                FeatureHubScrollCoordinator(state: FeatureHubNavigationState.shared)
                    .frame(width: 0, height: 0)
                // Keep one header child in the lazy stack. Inserting or
                // removing the restart notice as an offscreen lazy child
                // invalidates its visible range: the page jumps or goes
                // blank until the next scroll event.
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(hub.intro)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Keep the restart notice in the stable header.
                    if features.needsRestartToUnload {
                        restartCard
                    }
                }
                // The never-used offer shares one stable child with the summary.
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard
                    neverUsedCard
                }
                dynamicIslandCard
                ForEach(FeatureGroup.allCases.filter { $0 != .dynamicIsland && !AppFeature.hubFeatures(in: $0).isEmpty }, id: \.self) { group in
                    groupCard(group)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(hub.footerNote)
                    Text(hub.energyHelp)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }

    }

    /// Consumes a pending Feature Hub target and scrolls its row into view. Retried once
    /// after the first run-loop turn, the same allowance
    /// `SettingsSectionFocusModifier` gives a freshly installed Form to
    /// register its row identities.
    private func revealPendingFeatureTarget(using proxy: ScrollViewProxy) {
        if let request = router.pendingFeatureTarget {
            router.consumeFeatureTarget(id: request.id)
            revealID = request.id
            if request.feature.group == .dynamicIsland {
                if request.feature != .notch { islandExtensionsExpanded = true }
            } else {
                expandedGroups.insert(request.feature.group)
            }
            DispatchQueue.main.async {
                guard self.revealID == request.id else { return }
                proxy.scrollTo(request.feature.group, anchor: .top)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    guard self.revealID == request.id else { return }
                    reveal(request.feature, using: proxy)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard self.revealID == request.id else { return }
                        reveal(request.feature, using: proxy)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        guard self.revealID == request.id else { return }
                        clearHighlight()
                    }
                }
            }
        } else if let lastFeature = FeatureHubNavigationState.shared.lastNavigatedFeature {
            FeatureHubNavigationState.shared.lastNavigatedFeature = nil
            if lastFeature.group == .dynamicIsland {
                if lastFeature != .notch { islandExtensionsExpanded = true }
            } else {
                expandedGroups.insert(lastFeature.group)
            }
            DispatchQueue.main.async {
                proxy.scrollTo(lastFeature.group, anchor: .top)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    proxy.scrollTo(lastFeature, anchor: .center)
                }
            }
        }
    }

    private func reveal(_ feature: AppFeature, using proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(feature, anchor: .center)
            highlightedFeature = feature
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(feature, anchor: .center)
                highlightedFeature = feature
            }
        }
    }

    private func clearHighlight() {
        if reduceMotion {
            highlightedFeature = nil
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                highlightedFeature = nil
            }
        }
    }

    private var restartCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)
            Text(hub.restartNote)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Button(hub.restartButton) {
                FeatureRuntime.shared.relaunchApp()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The tally as a bar, with the two bulk actions beside it.
    private var summaryCard: some View {
        SettingsCard {
            HStack(spacing: 12) {
                Text(String(format: hub.activeCountFormat,
                            features.availableCount, features.installableCount))
                    .font(.headline)
                Spacer(minLength: 12)
                Button(hub.installAllButton) {
                    FeatureRuntime.shared.setAllAvailable(true)
                }
                .disabled(features.availableCount == features.installableCount)
                Button(hub.uninstallAllButton) {
                    FeatureRuntime.shared.setAllAvailable(false)
                }
                .disabled(features.availableCount == 0)
            }
            InstalledShareBar(installed: features.availableCount, total: features.installableCount)
        }
    }

    /// Installed switches that were never once turned on, offered as one
    /// batch. People come to this page to manage the app, so the offer waits
    /// here instead of interrupting anywhere else. Keep ends it for these
    /// features, and Undo puts back exactly what left.
    @ViewBuilder
    private var neverUsedCard: some View {
        if !recentlyUninstalled.isEmpty {
            SettingsCard {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text(hub.footerNote)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button(l10n.s.menuUndo, action: undoNeverUsedUninstall)
                }
            }
        } else if neverUsed.count >= Self.neverUsedMinimum {
            SettingsCard(title: hub.neverUsedTitle) {
                Text(String(format: hub.neverUsedMessageFormat,
                            neverUsed.map { $0.hubTitle(l10n.s, hub: hub) }.joined(separator: ", ")))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button(hub.neverUsedKeep, action: keepNeverUsed)
                    Button(hub.neverUsedUninstall, action: uninstallNeverUsed)
                }
            }
        }
    }

    private func refreshNeverUsed() {
        neverUsed = FeatureRuntime.shared.neverSwitchedOnFeatures()
    }

    private func uninstallNeverUsed() {
        // Read again at the click: a switch turned on in the panel since the
        // page appeared takes its feature out of the batch.
        let stillUnused = Set(FeatureRuntime.shared.neverSwitchedOnFeatures())
        let batch = neverUsed.filter(stillUnused.contains)
        guard !batch.isEmpty else {
            refreshNeverUsed()
            return
        }
        recentlyUninstalled = batch
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable(batch, false)
        }
    }

    /// Changing one's mind is also an answer to the offer, so the features
    /// that come back are kept and never offered again. None of them was
    /// ever on, and the reinstall leaves their switches off too.
    private func undoNeverUsedUninstall() {
        let batch = recentlyUninstalled
        recentlyUninstalled = []
        FeatureRuntime.shared.keep(batch)
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable(batch, true, enablingFirstInstalls: false)
        }
    }

    private func keepNeverUsed() {
        FeatureRuntime.shared.keep(neverUsed)
        withAnimation(.easeOut(duration: 0.22)) {
            refreshNeverUsed()
        }
    }




    /// The island stays near the top, with its additions in a group the user
    /// can close when they want a shorter catalog.
    private var dynamicIslandCard: some View {
        let members = AppFeature.features(in: .dynamicIsland)
        let installed = members.filter(\.isAvailable).count
        return SettingsCard {
            groupHeader(.dynamicIsland, installed: installed, total: members.count)
            FeatureHubRow(feature: .notch, hub: hub,
                          isHighlighted: highlightedFeature == .notch)
                .id(AppFeature.notch)
            DisclosureGroup(
                FeatureStrings.notch(l10n.language).modules,
                isExpanded: $islandExtensionsExpanded
            ) {
                if islandExtensionsExpanded {
                    VStack(spacing: 0) {
                        ForEach(members.filter { $0 != .notch }, id: \.self) { feature in
                            FeatureHubRow(feature: feature, hub: hub,
                                          isHighlighted: highlightedFeature == feature)
                                .id(feature)
                            if feature != members.last {
                                Divider().padding(.leading, 8)
                            }
                        }
                    }
                }
            }
        }
        .id(FeatureGroup.dynamicIsland)
    }

    /// Groups start open; LazyVStack builds distant groups as they enter view.
    /// Closing a group removes its feature rows until the user reopens it.
    private func groupCard(_ group: FeatureGroup) -> some View {
        let members = AppFeature.hubFeatures(in: group)
        let installed = members.filter(\.isAvailable).count
        return SettingsCard {
            DisclosureGroup(isExpanded: Binding(
                get: { expandedGroups.contains(group) },
                set: { expanded in
                    if expanded { expandedGroups.insert(group) }
                    else { expandedGroups.remove(group) }
                }
            )) {
                if expandedGroups.contains(group) {
                    VStack(spacing: 0) {
                        ForEach(members, id: \.self) { feature in
                            FeatureHubRow(
                                feature: feature,
                                hub: hub,
                                isHighlighted: highlightedFeature == feature
                            )
                            .id(feature)
                            if feature != members.last {
                                Divider().padding(.leading, 8)
                            }
                        }
                    }
                    if group == .monitor,
                       !FeatureVisibilitySupport.monitorFeatures.contains(where: \.isAvailable) {
                        Text(hub.monitorAllOffNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } label: {
                groupHeader(group, installed: installed, total: members.count)
            }
        }
        .id(group)
    }

    private func groupHeader(_ group: FeatureGroup, installed: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: group.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(groupTitle(group)).font(.headline)
            Spacer(minLength: 12)
            Text("\(installed)/\(total)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            InstalledShareBar(installed: installed, total: total)
                .controlSize(.small)
                .frame(width: 64)
        }
    }

    private func groupTitle(_ group: FeatureGroup) -> String {
        switch group {
        case .windowsDock: return hub.groupWindowsDock
        case .mouseKeyboard: return hub.groupMouseKeyboard
        case .clipboardFiles: return hub.groupClipboardFiles
        case .sound: return hub.groupSound
        case .energyDisplay: return hub.groupEnergyDisplay
        case .tools: return hub.groupTools
        case .dynamicIsland: return FeatureStrings.notch(l10n.language).title
        case .monitor: return hub.groupMonitor
        }
    }
}

private extension FeatureGroup {
    var symbolName: String {
        switch self {
        case .windowsDock: return "macwindow.on.rectangle"
        case .mouseKeyboard: return "computermouse"
        case .clipboardFiles: return "doc.on.clipboard"
        case .sound: return "speaker.wave.2.fill"
        case .energyDisplay: return "bolt.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .dynamicIsland: return AppFeature.notch.symbolName
        case .monitor: return "chart.line.uptrend.xyaxis"
        }
    }
}

/// The installed share as the system's own bar, the one picture of "how
/// much of this is on" that needs no reading.
private struct InstalledShareBar: View {
    let installed: Int
    let total: Int

    var body: some View {
        ProgressView(value: Double(min(installed, total)), total: Double(max(total, 1)))
            .progressViewStyle(.linear)
            .tint(Color.accentColor)
    }
}

// MARK: - Feature row

/// Icon, name and one line about the feature; small icons for the
/// permissions it can use and what it keeps alive; and the install action.
/// An installed feature with a page of its own opens it from the row.
private struct FeatureHubRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @State private var confirmingExtensions = false
    @State private var hovering = false
    @State private var showingMetadata = false
    let feature: AppFeature
    let hub: FeatureHubStrings
    var isHighlighted: Bool = false

    private var installed: Bool { feature.isAvailable }

    private var opensSettings: Bool { installed && feature.hasNavigableSettingsDestination }

    /// Extensions still installed under this row's feature; only the Dynamic
    /// Island has any. They do nothing without it, so its uninstall asks
    /// whether they leave too.
    private var installedExtensions: [AppFeature] {
        feature == .notch ? AppFeature.dynamicIslandExtensions.filter(\.isAvailable) : []
    }

    /// Set only while this Mac cannot run the feature and it is not yet
    /// installed, so an install that predates the check keeps an ordinary
    /// row with its settings and Uninstall reachable.
    private var unsupportedReason: String? { feature.installBlockedReason }

    private var accessibilityTitle: String {
        let title = feature.hubTitle(l10n.s, hub: hub)
        if feature == .notch { return "\(title). \(hub.experimentalBadge)" }
        return feature.isBeta ? "\(title). \(l10n.s.betaFeatureWarning)" : title
    }

    private var energyLabel: String {
        switch feature.energyProfile {
        case .idle: return hub.energyIdle
        case .mouse: return hub.energyMouse
        case .pointer: return hub.energyPointer
        case .keyboard: return hub.energyKeyboard
        case .inputs: return hub.energyInputs
        case .periodic: return hub.energyPeriodic
        }
    }

    private var energySymbols: [String] {
        switch feature.energyProfile {
        case .idle: return ["leaf"]
        case .mouse: return ["computermouse"]
        case .pointer: return ["hand.point.up.left"]
        case .keyboard: return ["keyboard"]
        case .inputs: return ["computermouse", "keyboard"]
        case .periodic: return ["clock.arrow.circlepath"]
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if opensSettings {
                Button {
                    FeatureHubNavigationState.shared.lastNavigatedFeature = feature
                    SettingsRouter.shared.request(feature.settingsDestination,
                                                  sidebarFeature: feature)
                } label: {
                    rowContent(showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(accessibilityTitle). \(feature.hubDescription(hub))")
                .accessibilityAddTraits(.isLink)
                .accessibilityRemoveTraits(.isButton)
            } else {
                rowContent(showsChevron: false)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(accessibilityTitle). \(feature.hubDescription(hub))")
                    .opacity(unsupportedReason == nil ? 1 : 0.4)
                    .saturation(unsupportedReason == nil ? 1 : 0)
            }
            metadata
            installAction
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(rowFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hovering = $0 }
        .alert(hub.notchUninstallTitle, isPresented: $confirmingExtensions) {
            Button(hub.notchUninstallWithExtensions) { flip(to: false, alongside: installedExtensions) }
            Button(hub.notchUninstallKeepExtensions) { flip(to: false) }
            Button(l10n.s.mediaCancel, role: .cancel) {}
        } message: {
            Text(String(format: hub.notchUninstallMessageFormat,
                        installedExtensions.map { $0.hubTitle(l10n.s, hub: hub) }
                            .joined(separator: ", ")))
        }
    }

    private var rowFill: Color {
        if isHighlighted { return Color.accentColor.opacity(0.10) }
        return hovering && opensSettings ? Color.primary.opacity(0.04) : Color.clear
    }

    private func rowContent(showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(feature.hubTitle(l10n.s, hub: hub))
                        .foregroundStyle(installed ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    if feature == .notch {
                        Text(hub.experimentalBadge.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(.orange)
                            .background(Capsule().fill(Color.orange.opacity(0.14)))
                            .accessibilityHidden(true)
                    }
                    if feature.isBeta {
                        Text(l10n.s.betaBadge)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor))
                            .accessibilityHidden(true)
                    }
                }
                Text(feature.hubDescription(hub))
                    .font(.caption)
                    .foregroundStyle(installed ? Color.secondary : Color.secondary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Use a readable label instead of a row of tiny, unexplained symbols.
    private var metadata: some View {
        let explanation = (feature.permissions.map { $0.name(hub) } + [energyLabel])
            .joined(separator: "\n")
        return Button(feature.permissions.isEmpty ? energyLabel : hub.tabPermissions) {
            showingMetadata.toggle()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.secondary)
        .help(explanation)
        .accessibilityLabel(explanation)
        .popover(isPresented: $showingMetadata) {
            // Symbols differ in width, so a centered icon column keeps the texts aligned.
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(feature.permissions, id: \.self) { permission in
                    GridRow {
                        Image(systemName: permission.symbolName)
                            .gridColumnAlignment(.center)
                            .accessibilityHidden(true)
                        Text(permission.name(hub))
                    }
                }
                GridRow {
                    HStack(spacing: 2) {
                        ForEach(energySymbols, id: \.self) { Image(systemName: $0) }
                    }
                    .accessibilityHidden(true)
                    Text(energyLabel)
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var installAction: some View {
        if installed {
            Button(hub.uninstallButton) {
                if installedExtensions.isEmpty { flip(to: false) } else { confirmingExtensions = true }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("\(hub.uninstallButton) \(accessibilityTitle)")
        } else if let reason = unsupportedReason {
            // .help() never fires on a disabled control, so the tooltip
            // has to sit on this wrapper. Flattening it loses the only
            // place the reason is shown.
            HStack(spacing: 0) {
                Button(hub.installButton) { flip(to: true) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)
                    .accessibilityLabel("\(hub.installButton) \(accessibilityTitle). \(reason)")
            }
            .help(reason)
        } else {
            Button(hub.installButton) { flip(to: true) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("\(hub.installButton) \(accessibilityTitle)")
        }
    }

    private func flip(to install: Bool, alongside companions: [AppFeature] = []) {
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable([feature] + companions, install)
        }
    }
}

// MARK: - Scroll position persistence for Features Hub

private struct FeatureHubScrollCoordinator: NSViewRepresentable {
    let state: FeatureHubNavigationState

    func makeNSView(context: Context) -> FeatureHubScrollObserverView {
        let view = FeatureHubScrollObserverView()
        view.state = state
        return view
    }

    func updateNSView(_ nsView: FeatureHubScrollObserverView, context: Context) {
        nsView.state = state
    }
}

private final class FeatureHubScrollObserverView: NSView {
    var state: FeatureHubNavigationState?
    private var isRestoring = false
    private weak var observedClipView: NSClipView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupObserver()
        } else {
            teardownObserver()
        }
    }

    private func setupObserver() {
        teardownObserver()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let scrollView = self.enclosingScrollView else { return }
            let clipView = scrollView.contentView
            self.observedClipView = clipView
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )

            // Restore scroll offset if saved and not navigating to a specific target
            if let saved = self.state?.scrollOffset, saved > 0, self.state?.lastNavigatedFeature == nil {
                self.isRestoring = true
                clipView.scroll(to: NSPoint(x: 0, y: saved))
                scrollView.reflectScrolledClipView(clipView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.isRestoring = false
                }
            }
        }
    }

    private func teardownObserver() {
        if let clipView = observedClipView {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: clipView)
            observedClipView = nil
        }
    }

    @objc private func boundsDidChange(_ notification: Notification) {
        guard !isRestoring, let clipView = observedClipView else { return }
        let currentY = clipView.bounds.origin.y
        state?.scrollOffset = currentY
    }

    deinit {
        teardownObserver()
    }
}
