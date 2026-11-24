// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Dock & Applications page: Dock Preview and Dock clicks, then the
/// App Switcher below them.
struct DockSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var dockPreview = DockPreviewService.shared
    @AppStorage(DefaultsKey.dockPreviewEnabled) private var dockPreviewEnabled = false
    @AppStorage(DefaultsKey.previewSize) private var previewSize = "normal"
    @AppStorage(DefaultsKey.dockPreviewCurrentSpaceOnly) private var dockPreviewCurrentSpaceOnly = false
    @AppStorage(DefaultsKey.dockPreviewBackgroundOpacity) private var dockPreviewBackgroundOpacity = 1.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.dockPreviewOpenDelay) private var dockPreviewOpenDelay = DockPreviewSupport.defaultOpenDelayMilliseconds
    @AppStorage(DefaultsKey.dockPreviewOrderByCreation) private var dockPreviewOrderByCreation = false
    @AppStorage(DefaultsKey.dockPreviewKeepDockVisible) private var dockPreviewKeepDockVisible = false
    @AppStorage(DefaultsKey.minimalWindowPreviews) private var minimalPreviews = false
    @AppStorage(DefaultsKey.dockClickMinimize) private var dockClickMinimize = false
    @AppStorage(DefaultsKey.dockClickHide) private var dockClickHide = false
    @AppStorage(DefaultsKey.dockClickCycleWindows) private var dockClickCycleWindows = false
    @AppStorage(DefaultsKey.switcherEnabled) private var switcherEnabled = true
    @State private var showingCurrentSpaceInfo = false
    @State private var isDockAutohideEnabled = DockAutohideHold.isAutoHideEnabled

    private var dockPreviewInstalled: Bool { AppFeature.dockPreview.isAvailable }
    private var dockPreviewEngaged: Bool { dockPreviewInstalled && dockPreviewEnabled }
    private var dockClickEngaged: Bool { dockClickMinimize || dockClickHide || dockClickCycleWindows }
    private var switcherEngaged: Bool { switcherEnabled && AppFeature.switcher.isAvailable }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dockPreviewCard
                    .settingsSectionAnchor(.dock, cornerRadius: 16)
                SwitcherSettingsSection()
                // One set of permission cards for the whole page. The switcher
                // belongs to this page, so the Accessibility check covers it;
                // its window shortcut shows thumbnails in every layout, so it
                // needs Screen Recording whenever it is on.
                if needsAccessibility, !permissions.accessibility {
                    SettingsCard(title: l10n.s.permissionRequired) {
                        PermissionRow(kind: .accessibility)
                    }
                    .transition(.settingsReveal)
                }
                if dockPreviewEngaged || switcherEngaged, !permissions.screenRecording {
                    SettingsCard {
                        PermissionRow(kind: .screenRecording)
                    }
                    .transition(.settingsReveal)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .onAppear {
            isDockAutohideEnabled = DockAutohideHold.isAutoHideEnabled
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.dock.prefchanged"))) { _ in
            isDockAutohideEnabled = DockAutohideHold.isAutoHideEnabled
        }
        .settingsExpansionAnimation(value: [dockPreviewEngaged, dockClickEngaged, switcherEngaged,
            permissions.accessibility, permissions.screenRecording, dockPreviewBackgroundIsGlass])
    }

    private var dockPreviewCard: some View {
        SettingsCard(symbol: "dock.rectangle", title: l10n.s.dockPreviewName, caption: dockPreviewCaption, headerAccessory: {
            PermissionGatedToggle(l10n.s.dockPreviewName, isOn: Binding(
                get: { dockPreviewEngaged },
                set: { enabled in
                    dockPreviewEnabled = enabled
                    FeatureRuntime.shared.setAvailable([.dockPreview], enabled)
                    DockPreviewService.shared.syncWithPreferences()
                }
            ), requiring: [.accessibility, .screenRecording], feature: .dockPreview)
                .labelsHidden()
        }) {
            if dockPreviewEngaged {
                VStack(alignment: .leading, spacing: 13) {
                    WindowPreviewExclusionsList(key: DefaultsKey.windowPreviewExcludedApps)
                    SettingsControlRow(title: l10n.s.previewSizeLabel) {
                        Picker(l10n.s.previewSizeLabel, selection: $previewSize) {
                            Text(l10n.s.previewSizeSmall).tag("small")
                            Text(l10n.s.previewSizeNormal).tag("normal")
                            Text(l10n.s.previewSizeLarge).tag("large")
                            Text(l10n.s.previewSizeXLarge).tag("xlarge")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        .onChange(of: previewSize) { _, _ in
                            DockPreviewService.shared.syncWithPreferences()
                        }
                    }
                    SettingsControlRow(title: l10n.s.dockPreviewOpenDelay,
                                       caption: l10n.s.dockPreviewOpenDelayCaption) {
                        Picker(l10n.s.dockPreviewOpenDelay, selection: dockPreviewHoverDelayBinding) {
                            if ![200, 350].contains(dockPreviewHoverDelayBinding.wrappedValue) {
                                Text("\(dockPreviewHoverDelayBinding.wrappedValue) ms").tag(dockPreviewHoverDelayBinding.wrappedValue)
                            }
                            Text(l10n.s.dockPreviewDelayDefault).tag(200)
                            Text(l10n.s.dockPreviewDelayLonger).tag(350)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    SettingsControlRow(title: l10n.s.dockPreviewCurrentSpaceOnly,
                                       caption: l10n.s.dockPreviewCurrentSpaceOnlyCaption) {
                        HStack(spacing: 8) {
                            if !dockPreviewCurrentSpaceOnly {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .contentShape(Rectangle())
                                    .onHover { hovering in
                                        showingCurrentSpaceInfo = hovering
                                    }
                                    .popover(isPresented: $showingCurrentSpaceInfo, arrowEdge: .top) {
                                        Text(l10n.s.dockPreviewCurrentSpaceOnlyInfo)
                                            .font(.callout)
                                            .padding(12)
                                            .frame(width: 280)
                                    }
                            }
                            Toggle(l10n.s.dockPreviewCurrentSpaceOnly, isOn: $dockPreviewCurrentSpaceOnly)
                                .labelsHidden()
                                .onChange(of: dockPreviewCurrentSpaceOnly) { _, _ in
                                    DockPreviewService.shared.syncWithPreferences()
                                }
                        }
                    }
                    if !dockPreviewBackgroundIsGlass {
                        SettingsControlRow(title: l10n.s.dockPreviewBackgroundOpacity,
                                           caption: l10n.s.dockPreviewBackgroundOpacityCaption) {
                            SettingsValueSlider(title: l10n.s.dockPreviewBackgroundOpacity,
                                value: dockPreviewBackgroundOpacityBinding,
                                range: DockPreviewSupport.backgroundOpacityRange, step: 0.05,
                                readout: "\(dockPreviewBackgroundOpacityPercent)%", usesSystemAppearance: true)
                                .frame(width: 140)
                        }
                        .transition(.settingsReveal)
                    }
                    SettingsControlRow(title: l10n.s.dockPreviewKeepDockVisible,
                                       caption: l10n.s.dockPreviewKeepDockVisibleCaption) {
                        Toggle(l10n.s.dockPreviewKeepDockVisible, isOn: Binding(
                            get: { isDockAutohideEnabled ? dockPreviewKeepDockVisible : true },
                            set: { dockPreviewKeepDockVisible = $0 }
                        ))
                            .labelsHidden()
                            .onChange(of: dockPreviewKeepDockVisible) { _, _ in
                                dockPreview.syncWithPreferences()
                            }
                    }
                    .disabled(!isDockAutohideEnabled || (!DockAutohideHold.isSupported && !dockPreviewKeepDockVisible))
                    .opacity(isDockAutohideEnabled ? 1 : 0.55)
                    SettingsControlRow(title: l10n.s.dockPreviewOrderByCreation,
                                       caption: l10n.s.dockPreviewOrderByCreationCaption) {
                        Toggle(l10n.s.dockPreviewOrderByCreation, isOn: $dockPreviewOrderByCreation).labelsHidden()
                    }
                    SettingsControlRow(title: l10n.s.minimalWindowPreviews,
                                       caption: l10n.s.minimalWindowPreviewsCaption) {
                        Toggle(l10n.s.minimalWindowPreviews, isOn: $minimalPreviews).labelsHidden()
                    }
                }
                .padding(.leading, settingsRowTextInset)
            }
            if AppFeature.dockClick.isPresentInControls() {
                Divider()
                DockClickSettings()
                    .settingsSectionAnchor(.dockClick, cornerRadius: 12)
            }
        }
    }

    // MARK: - State

    /// Dock Preview and every Dock click action work through Accessibility;
    /// the catalog knows which of them are on right now.
    private var needsAccessibility: Bool {
        FeatureVisibilitySupport.isPermissionNeeded(
            on: .dock, activeFeatures: AppFeature.activeFeatures(using: .accessibility))
    }

    private var dockPreviewCaption: String? {
        guard dockPreviewEnabled else { return nil }
        if !permissions.accessibility { return "\(l10n.s.permissionRequired): \(l10n.s.permissionAccessibility)" }
        if !permissions.screenRecording { return "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)" }
        switch dockPreview.blockedReason {
        case .dockUnavailable: return l10n.s.dockPreviewDockUnavailable
        default:
            return nil
        }
    }

    /// The slider only fades the classic material. Liquid Glass takes its
    /// transparency from System Settings, so the slider has nothing to change.
    private var dockPreviewBackgroundIsGlass: Bool {
        HUDBackdrop.drawsLiquidGlass(reduceTransparency: reduceTransparency)
    }

    private var dockPreviewBackgroundOpacityBinding: Binding<Double> {
        Binding(
            get: { DockPreviewSupport.sanitizedBackgroundOpacity(dockPreviewBackgroundOpacity) },
            set: { dockPreviewBackgroundOpacity = DockPreviewSupport.sanitizedBackgroundOpacity($0) }
        )
    }

    private var dockPreviewBackgroundOpacityPercent: Int {
        Int((DockPreviewSupport.sanitizedBackgroundOpacity(dockPreviewBackgroundOpacity) * 100).rounded())
    }

    private var dockPreviewHoverDelayBinding: Binding<Int> {
        Binding(
            get: {
                DockPreviewSupport.sanitizedOpenDelay(milliseconds: self.dockPreviewOpenDelay)
            },
            set: { newValue in
                self.dockPreviewOpenDelay = newValue
            }
        )
    }
}

