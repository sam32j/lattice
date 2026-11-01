// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubView: View {
    var notchSize: CGSize? = nil
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var launcher = LatticeHubService.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var recorder = ScreenRecorderService.shared
    @ObservedObject var editing = LatticeHubService.shared.editingPresentation
    @StateObject var dragSession = HubDragSession()
    @State var hoveredItem: LatticeHubItem?

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
                        editingContent.padding(.top, 12)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                }
            }
            if notchSize == nil {
                footer.padding(.top, 12)
            }
        }
        .padding(notchSize == nil ? 16 : 0)
        .frame(width: notchSize?.width ?? 420, height: notchSize?.height, alignment: .top)
        .fixedSize(horizontal: false, vertical: notchSize == nil)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            if notchSize == nil { launcher.updatePanelSize(size) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background { if notchSize == nil { HUDBackdrop(cornerRadius: 22, contrast: .high) } }
        .clipShape(RoundedRectangle(cornerRadius: notchSize == nil ? 22 : 0, style: .continuous))
        .transaction { if reduceMotion { $0.animation = nil } }
        .notchBand(leading: {
            if notchSize != nil, let utility = launcher.activeUtility {
                NotchBandBackButton(title: title(for: utility), action: launcher.closeUtility)
            }
        }, trailing: {
            if notchSize != nil {
                if launcher.activeUtility == .recentCaptures {
                    NotchClearCapturesButton()
                } else if launcher.activeUtility == nil {
                    if launcher.isEditing {
                        NotchIconButton(symbol: "checkmark",
                                        title: FeatureStrings.notch(l10n.language).customizeHub,
                                        selected: true, hasBackdrop: false) {
                            withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = false }
                        }
                    } else {
                        toolsMenuButton
                    }
                }
            }
        })
        .onChange(of: launcher.canManageTools) { _, available in
            if !available {
                launcher.isEditing = false
            }
        }
        .onChange(of: features.revision, initial: true) { launcher.refreshAvailability() }
        .onChange(of: launcher.presentationID) { _, _ in
            hoveredItem = nil
            dragSession.cancel()
        }
        .onChange(of: launcher.activeUtility) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.isEditing) { _, _ in dragSession.cancel() }
        .onChange(of: editing.isPresented) { _, _ in refreshIslandLayout() }
        .onChange(of: editing.optionsHeight) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.editingOptionsItem) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.hiddenItemsRaw) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.visibleControls.count) { _, _ in refreshIslandLayout() }
        .onChange(of: launcher.hiddenControls.count) { _, _ in refreshIslandLayout() }
        .onDisappear { dragSession.cancel() }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: notchSize == nil ? 12 : 6) {
            if launcher.activeUtility == nil {
                HubQuickControls(notchSize: notchSize, isEditing: launcher.isEditing,
                                 dragSession: dragSession) { launcher.hide() }
                    .frame(height: notchSize == nil ? nil : launcher.notchControlsHeight, alignment: .top)
            }
            if let utility = launcher.activeUtility, utility.isAvailable() {
                LatticeHubHostedUtility(item: utility, notchSize: notchSize) { launcher.closeUtility() }
            } else if launcher.visibleCount == 0 {
                emptyState
            } else {
                grid
            }
        }
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

    // Chrome, editing tray, grid and metadata have dedicated view files.
}
