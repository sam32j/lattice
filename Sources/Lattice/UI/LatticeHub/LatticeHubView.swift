// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubView: View {
    var notchSize: CGSize? = nil
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var launcher = LatticeHubService.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var recorder = ScreenRecorderService.shared
    @State var hoveredItem: LatticeHubItem?
    @State var draggingItem: LatticeHubItem?

    private var optionsItem: LatticeHubItem? { launcher.editingOptionsItem }
    @AppStorage(DefaultsKey.clipboardHistoryEnabled) private var clipboardEnabled = false

    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: notchSize == nil ? 10 : 6),
              count: notchSize == nil ? LatticeHubService.columns : NotchSupport.toolColumns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if notchSize == nil { header }
            if notchSize != nil, launcher.activeUtility == nil, launcher.isEditing {
                editHint
            }
            if notchSize == nil, launcher.activeUtility == nil, !launcher.isEditing {
                HubQuickControls { launcher.hide() }
            }
            if let utility = launcher.activeUtility, utility.isAvailable() {
                LatticeHubHostedUtility(item: utility, notchSize: notchSize) { launcher.closeUtility() }
            } else if launcher.visibleItems.isEmpty && !launcher.isEditing {
                emptyState
            } else {
                grid
            }
            if launcher.activeUtility == nil, launcher.isEditing,
               let optionsItem, hasQuickOptions(optionsItem) {
                LatticeHubOptionsCard(item: optionsItem, notchSize: notchSize,
                                      title: title(for: optionsItem), icon: icon(for: optionsItem)) {
                    withAnimation(.easeOut(duration: 0.15)) { launcher.editingOptionsItem = nil }
                }
            }
            if launcher.activeUtility == nil, launcher.isEditing, !launcher.hiddenItems.isEmpty {
                hiddenTray
            }
            if notchSize == nil { footer }
        }
        .padding(notchSize == nil ? 16 : 0)
        .frame(width: notchSize?.width ?? 420)
        .background { if notchSize == nil { HUDBackdrop(cornerRadius: 22, contrast: .high) } }
        .clipShape(RoundedRectangle(cornerRadius: notchSize == nil ? 22 : 0, style: .continuous))
        .notchBand(leading: {
            if notchSize != nil, let utility = launcher.activeUtility {
                NotchBandBackButton(title: title(for: utility), action: launcher.closeUtility)
            }
        }, trailing: {
            if notchSize != nil, launcher.activeUtility == nil {
                NotchIconButton(symbol: launcher.isEditing ? "checkmark" : "slider.horizontal.3",
                                title: FeatureStrings.notch(l10n.language).customizeTools, selected: launcher.isEditing) {
                    withAnimation(.easeOut(duration: 0.15)) { launcher.isEditing.toggle() }
                }
            }
        })
        .onChange(of: features.revision, initial: true) { launcher.refreshAvailability() }
        .onChange(of: launcher.presentationID) { _, _ in
            hoveredItem = nil
            draggingItem = nil
        }
        .onChange(of: launcher.activeUtility) { _, _ in launcher.refreshPanelLayout() }
        .onChange(of: launcher.isEditing) { _, _ in
            launcher.editingOptionsItem = nil
            launcher.refreshPanelLayout()
        }
        .onChange(of: launcher.editingOptionsItem) { _, _ in launcher.refreshPanelLayout() }
        .onChange(of: clipboardEnabled) { _, _ in launcher.refreshPanelLayout() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            ZStack {
                BrandMark(width: 52, tint: colorScheme == .light ? Color(white: 0.03) : .white)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
                HStack {
                    if launcher.activeUtility != nil {
                        backButton
                    } else {
                        closeButton
                    }
                    Spacer()
                    if launcher.activeUtility != nil {
                        closeButton
                    } else {
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { launcher.isEditing.toggle() }
                        } label: {
                            Image(systemName: launcher.isEditing ? "checkmark.circle.fill" : "slider.horizontal.3")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(launcher.isEditing ? Color.accentColor : Color.secondary)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .help(l10n.s.launcherEditHint)
                        .accessibilityLabel(l10n.s.menuSettings)
                    }
                }
            }
            if launcher.isEditing, launcher.activeUtility == nil { editHint }
        }
    }

    private var editHint: some View {
        Text(l10n.s.launcherEditHint)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var closeButton: some View {
        Button { launcher.hide() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(l10n.s.menuClose)
        .accessibilityLabel(l10n.s.menuClose)
    }

    private var backButton: some View {
        Button { launcher.closeUtility() } label: {
            Image(systemName: "chevron.backward.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(l10n.s.navigationBack)
        .accessibilityLabel(l10n.s.navigationBack)
    }

    // Grid and cell implementations are in LatticeHubGrid.swift

    private var hiddenTray: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.s.launcherAddSection.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(launcher.hiddenItems) { item in
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { launcher.setHidden(item, false) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text(title(for: item))
                            }
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text(l10n.s.launcherEmptyState)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            if GlobalShortcutRole.quickLauncher.savedShortcut.isValid {
                Image(systemName: "keyboard")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                Text(GlobalShortcutRole.quickLauncher.savedShortcut.displayString)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("Esc")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

    // Metadata is implemented in LatticeHubMetadata.swift
}

typealias QuickLauncherView = LatticeHubView

