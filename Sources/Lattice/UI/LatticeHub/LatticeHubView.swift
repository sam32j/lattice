// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct LatticeHubView: View {
    var notchSize: CGSize? = nil
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var launcher = LatticeHubService.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var recorder = ScreenRecorderService.shared
    @ObservedObject var appUpdates = AppUpdatesService.shared
    @ObservedObject var editing = LatticeHubService.shared.editingPresentation
    @ObservedObject var service = NotchService.shared
    @ObservedObject var updates = UpdateService.shared
    @ObservedObject var notifications = NotchNotificationService.shared
    @ObservedObject var dnd = DoNotDisturbState.shared
    @ObservedObject var systemNav = SystemNavigationState.shared
    @StateObject var dragSession = HubDragSession()

    // Keep the common header outside the page switch. The two page bodies
    // overlap at their natural heights; neither is animated vertically.
    private enum FloatingHUDPage {
        case root
        case utility(LatticeHubItem)
    }
    @State private var outgoingHUDPage: FloatingHUDPage?
    @State private var hudFadeProgress = 1.0
    @State private var hudFadeGeneration = 0

    // Track only the editor's actual, independently animated height. The
    // grid viewport gives up space from its BOTTOM if the panel reaches the
    // screen limit; the header, controls, and first grid row never move.
    @State private var floatingAccordionHeight: CGFloat = 0
    @State private var floatingEditorNaturalHeight: CGFloat = 1

    private var floatingControlsHeight: CGFloat {
        let rows = HubControlAction.rows(launcher.visibleControls)
        let count = (rows.first.isEmpty ? 0 : 1) + (rows.second.isEmpty ? 0 : 1)
        return count == 0 ? 0 : CGFloat(count) * 32 + CGFloat(count - 1) * 6 + 8
    }

    // A stable presentation-time limit shared by the grid and Manage Tools.
    // Never derive this from the panel's animated frame.
    private var floatingHeightBudget: CGFloat {
        max(240, launcher.floatingPanelHeightBudget)
    }

    private var floatingEditorViewportLimit: CGFloat {
        // Reserve room for at least one visible tool row; the editor itself
        // scrolls if the available-tray content exceeds the screen budget.
        max(80, floatingHeightBudget - floatingControlsHeight - 94 - 80)
    }

    private var floatingGridViewportHeight: CGFloat {
        // Header, surrounding padding, vertical gaps and rounded corners.
        max(80, floatingHeightBudget - floatingControlsHeight - 94 - floatingAccordionHeight)
    }

    private var optionsItem: LatticeHubItem? {
        launcher.editingOptionsItem ?? editing.outgoingOptions
    }

    var customizationText: HubCustomizationStrings { FeatureStrings.hubCustomization(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if notchSize == nil {
                header
                    .transaction { $0.animation = nil }
                    .padding(.bottom, 12)
            }
            if notchSize != nil, launcher.activeUtility == nil {
                mainContent
                    .frame(height: islandMainHeight, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("hub-main-content")
            } else { mainContent }
            if launcher.activeUtility == nil {
                if notchSize != nil {
                    editingContent.padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(editing.isExpanded ? 1 : 0)
                        .allowsHitTesting(launcher.isEditing && editing.isExpanded)
                        .accessibilityHidden(!editing.isExpanded)
                } else {
                    HubAccordion(isExpanded: editing.isExpanded) {
                        ScrollView(.vertical) {
                            editingContent.padding(.top, 12)
                                .fixedSize(horizontal: false, vertical: true)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                    if height > 0, abs(floatingEditorNaturalHeight - height) > 0.5 {
                                        floatingEditorNaturalHeight = height
                                    }
                                }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(height: min(floatingEditorNaturalHeight,
                                           floatingEditorViewportLimit))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        // This is a presentation height, not a desired height.
                        // The animator above already interpolates it.
                        if abs(floatingAccordionHeight - height) > 0.5 {
                            floatingAccordionHeight = height
                        }
                    }
                }
            }
        }
        .padding(notchSize == nil ? 16 : 0)
        .frame(width: notchSize?.width ?? 420,
               height: notchSize?.height,
               alignment: .top)
        .fixedSize(horizontal: false, vertical: notchSize == nil)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            if notchSize == nil { launcher.updatePanelSize(size) }
        }
        // Native window bounds and the intrinsic HUD content are different
        // sizes for most of a grow/shrink animation. Never let the hosting view
        // center that oversized content inside the smaller window: align its
        // natural-height page at the TOP and clip only at the bottom edge.
        .modifier(HubTopPinnedViewport(enabled: notchSize == nil))
        .frame(maxHeight: .infinity, alignment: .top)
        .background { if notchSize == nil { HUDBackdrop(cornerRadius: 22, contrast: .standard) } }
        .clipShape(RoundedRectangle(cornerRadius: notchSize == nil ? 22 : 0, style: .continuous))
        .transaction { if reduceMotion { $0.animation = nil } }
        .notchBand(leading: {
            if notchSize != nil {
                if let utility = launcher.activeUtility {
                    let backTitle: String = {
                        if utility == .system, systemNav.selectedMetric != nil {
                            return utility.title(language: l10n.language)
                        } else if utility == .deviceControls, DeviceControlsNavigationState.shared.currentSubpage == .appVolumes {
                            return utility.title(language: l10n.language)
                        } else {
                            return SettingsFollowupStrings.text(.allTools, l10n.language)
                        }
                    }()
                    NotchBandBackButton(title: backTitle, showsTitle: true, action: {
                        if let custom = NotchService.shared.customBackAction, custom() { return }
                        if utility == .deviceControls, DeviceControlsNavigationState.shared.currentSubpage == .appVolumes {
                            DeviceControlsNavigationState.shared.currentSubpage = .main
                        } else if utility == .system, systemNav.selectedMetric != nil {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                systemNav.reset()
                                NotchService.shared.refreshPresentation()
                            }
                            SystemMonitor.shared.scheduleCPUWarmUpIfNeeded()
                        } else {
                            if utility == .deviceControls {
                                DeviceControlsNavigationState.shared.resetSubpage()
                            }
                            if utility == .system {
                                systemNav.reset()
                            }
                            launcher.closeUtility()
                        }
                    })
                } else if launcher.isEditing {
                    Text(NotchQuickActionsCopy.editingTools(l10n.language))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                } else {
                    HStack(spacing: 3) {
                        islandToolsMenuButton
                        if updateOffered {
                            islandUpdateButton
                        }
                    }
                }
            }
        }, trailing: {
            if notchSize != nil {
                if launcher.activeUtility != nil {
                    HStack(spacing: 3) {
                        if launcher.activeUtility == .recentCaptures {
                            NotchClearCapturesButton()
                        }
                        if launcher.activeUtility == .system {
                            islandActivityMonitorButton
                        }
                        islandPinButton
                    }
                } else {
                    HStack(spacing: 3) {
                        if !launcher.isEditing {
                            if service.modules.contains(.notifications) {
                                islandNotificationButton
                            }
                            if service.modules.contains(.downloads) {
                                islandDownloadButton
                            }
                            islandPinButton
                        } else {
                            doneEditingButton
                        }
                    }
                }
            }
        })
        .onAppear { dnd.refresh() }
        .onChange(of: launcher.canManageTools) { _, available in
            if !available {
                launcher.isEditing = false
            }
        }
        .onChange(of: features.revision, initial: true) { launcher.refreshAvailability() }
        .onChange(of: launcher.presentationID) { _, _ in
            dragSession.cancel()
            dnd.refresh()
        }
        .onChange(of: launcher.activeUtility) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.isEditing) { _, _ in dragSession.cancel() }
        .onChange(of: editing.isPresented) { _, _ in refreshIslandLayout() }
        .onChange(of: editing.optionsHeight) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.editingOptionsItem) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.hiddenItemsRaw) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.visibleControls.count) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.hiddenControls.count) { _, _ in refreshIslandLayout() }
        .onChange(of: appUpdates.items.count) { _, _ in refreshIslandLayout() }
        .onChange(of: DeviceControlsNavigationState.shared.contentHeight) { _, _ in refreshIslandLayout() }
        .onChange(of: SystemNavigationState.shared.selectedMetric) { _, _ in refreshIslandLayout() }
        .onDisappear { dragSession.cancel() }
    }

    @ViewBuilder
    private var rootContent: some View {
        VStack(alignment: .leading, spacing: notchSize == nil ? 12 : 6) {
            HubQuickControls(notchSize: notchSize, isEditing: launcher.isEditing,
                             dragSession: dragSession) { launcher.hide() }
                .frame(height: notchSize == nil ? nil : launcher.notchControlsHeight, alignment: .top)
            if notchSize != nil {
                HubIslandWidgetSection(isEditing: launcher.isEditing)
            }
            if launcher.visibleCount == 0 {
                emptyState
            } else if notchSize == nil {
                // Only the tiles scroll when the root is too tall. The
                // common header and quick controls never move on return.
                ScrollView(.vertical) {
                    grid
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(HubToolLayout.hudHeight(count: launcher.visibleCount),
                                   floatingGridViewportHeight))
            } else {
                grid
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if notchSize == nil {
            // Both pages participate in height measurement, but neither
            // slides. The native panel animates its bottom edge independently.
            // Removing the outgoing page after the fade lets the panel shrink.
            ZStack(alignment: .topLeading) {
                floatingHUDPage(for: launcher.activeUtility.map(FloatingHUDPage.utility) ?? .root)
                    .opacity(hudFadeProgress)
                    .allowsHitTesting(outgoingHUDPage == nil)
                if let outgoingHUDPage {
                    floatingHUDPage(for: outgoingHUDPage)
                        .opacity(1 - hudFadeProgress)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onChange(of: launcher.activeUtility) { previous, _ in
                crossfadeFloatingHUD(from: previous)
            }
            .onDisappear {
                hudFadeGeneration += 1
                outgoingHUDPage = nil
                hudFadeProgress = 1
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if launcher.activeUtility == nil {
                    HubQuickControls(notchSize: notchSize, isEditing: launcher.isEditing,
                                     dragSession: dragSession) { launcher.hide() }
                        .frame(height: launcher.notchControlsHeight, alignment: .top)
                        .transition(.opacity)
                    HubIslandWidgetSection(isEditing: launcher.isEditing)
                        .transition(.opacity)
                }
                if let utility = launcher.activeUtility, utility.isAvailable() {
                    LatticeHubHostedUtility(item: utility, notchSize: notchSize) { launcher.closeUtility() }
                        .transition(.opacity)
                } else if launcher.visibleCount == 0 {
                    emptyState
                        .transition(.opacity)
                } else {
                    grid
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func floatingHUDPage(for page: FloatingHUDPage) -> some View {
        switch page {
        case .root:
            rootContent
        case .utility(let utility):
            if utility.isAvailable() {
                LatticeHubHostedUtility(item: utility, notchSize: nil) { launcher.closeUtility() }
                    .id(utility)
            } else {
                rootContent
            }
        }
    }

    private func crossfadeFloatingHUD(from previous: LatticeHubItem?) {
        hudFadeGeneration += 1
        let generation = hudFadeGeneration
        guard !reduceMotion else {
            outgoingHUDPage = nil
            hudFadeProgress = 1
            return
        }

        // No animation transaction wraps this layout change. Only the two
        // opacity values animate; each page stays fixed at the panel's top.
        updateHUDWithoutAnimation {
            outgoingHUDPage = previous.map(FloatingHUDPage.utility) ?? .root
            hudFadeProgress = 0
        }
        DispatchQueue.main.async {
            guard hudFadeGeneration == generation else { return }
            withAnimation(.easeInOut(duration: 0.18), completionCriteria: .logicallyComplete) {
                hudFadeProgress = 1
            } completion: {
                guard hudFadeGeneration == generation else { return }
                updateHUDWithoutAnimation {
                    outgoingHUDPage = nil
                }
            }
        }
    }

    // Inserting/removing the outgoing page must never start a layout animation.
    // The explicit opacity animation above is the only page transition.
    private func updateHUDWithoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { updates() }
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: notchSize == nil ? 12 : 6) {
            if let optionsItem, hasQuickOptions(optionsItem), notchSize == nil {
                LatticeHubOptionsCard(item: optionsItem, notchSize: notchSize,
                                      title: title(for: optionsItem), icon: icon(for: optionsItem)) {
                    withAnimation(.easeInOut(duration: 0.22)) { launcher.editingOptionsItem = nil }
                }
            } else if let optionsItem, hasQuickOptions(optionsItem) {
                LatticeHubOptionsCard(item: optionsItem, notchSize: notchSize,
                    title: title(for: optionsItem), icon: icon(for: optionsItem)) {
                    launcher.editingOptionsItem = nil
                }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { editing.measureOptions($0) }
            }
            hiddenTray
        }
    }

    private func refreshIslandLayout() {
        if notchSize != nil { NotchService.shared.refreshPresentation() }
    }

    var updateOffered: Bool {
        if case .available = updates.state { return true }
        return false
    }

    private var notificationSymbol: String {
        if dnd.isActive {
            return "moon.fill"
        } else if !notifications.items.isEmpty {
            return "bell.badge.fill"
        } else {
            return "bell"
        }
    }

    private var islandNotificationButton: some View {
        NotchIconButton(
            symbol: notificationSymbol,
            title: NotchModule.notifications.title(l10n.language),
            selected: false,
            hasBackdrop: false,
            tint: dnd.isActive ? Color(red: 0.72, green: 0.56, blue: 1.0) : nil
        ) {
            service.select(.notifications)
        }
    }

    private var islandDownloadButton: some View {
        NotchIconButton(
            symbol: "arrow.down.circle",
            title: NotchModule.downloads.title(l10n.language),
            selected: false,
            hasBackdrop: false
        ) {
            service.select(.downloads)
        }
    }

    private var islandPinButton: some View {
        NotchIconButton(
            symbol: service.pinned ? "pin.fill" : "pin",
            title: service.pinned ? FeatureStrings.notch(l10n.language).unpin : FeatureStrings.notch(l10n.language).pin,
            selected: service.pinned,
            hasBackdrop: false
        ) {
            service.pinned.toggle()
            launcher.isPinned = service.pinned
        }
    }

    private var islandActivityMonitorButton: some View {
        Button {
            let fallback = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
            let url = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") ?? fallback
            NSWorkspace.shared.open(url)
        } label: {
            HubActivityMonitorIcon()
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 9))
        .focusable(false)
        .help(l10n.s.monitorOpenActivityMonitor)
        .accessibilityLabel(l10n.s.monitorOpenActivityMonitor)
    }

    private var islandUpdateButton: some View {
        Button(action: service.showUpdate) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 9))
        .focusable().focusEffectDisabled()
        .help(updateTooltip)
        .accessibilityLabel(updateTooltip)
    }

    // Chrome, editing tray, grid and metadata have dedicated view files.
}

// MARK: - Floating HUD hosting geometry

/// The hosting window owns the viewport height. The content owns its natural
/// height (measured above), but that height must not drive the rendered root
/// view outside the window while AppKit is animating the frame.
///
/// A normal fixed-size SwiftUI root can be CENTERED by NSHostingController when
/// it is taller than its window. This layout instead fills the current window
/// proposal and pins its potentially taller child to the top-left, so only the
/// BOTTOM of the page is revealed or covered when the panel resizes.
private struct HubTopPinnedViewport: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            HubTopPinnedLayout { content }
        } else {
            content
        }
    }
}

private struct HubTopPinnedLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let natural = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        // At fitting-size time the height is unspecified: report the true
        // intrinsic height. During a native resize it is finite: match the
        // window's viewport rather than forcing the hosting root to overflow.
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? natural.width
        let height = proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? natural.height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        child.place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                    proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}
