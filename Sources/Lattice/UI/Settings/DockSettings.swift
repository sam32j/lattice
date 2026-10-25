// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Dock page: Dock Preview, Dock clicks and the window previews Dock
/// Preview shares with the switcher.
struct DockSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var dockPreview = DockPreviewService.shared
    @AppStorage(DefaultsKey.dockPreviewEnabled) private var dockPreviewEnabled = false
    @AppStorage(DefaultsKey.dockPreviewCurrentSpaceOnly) private var dockPreviewCurrentSpaceOnly = false
    @AppStorage(DefaultsKey.dockPreviewBackgroundOpacity) private var dockPreviewBackgroundOpacity = 1.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.dockPreviewOpenDelay) private var dockPreviewOpenDelay = DockPreviewSupport.defaultOpenDelayMilliseconds
    @AppStorage(DefaultsKey.dockPreviewQuitAppOnClose) private var dockPreviewQuitAppOnClose = false
    @AppStorage(DefaultsKey.dockPreviewOrderByCreation) private var dockPreviewOrderByCreation = false
    @AppStorage(DefaultsKey.dockPreviewKeepDockVisible) private var dockPreviewKeepDockVisible = false
    @State private var showingDockInfo = false

    private var pages: SettingsPageStrings { FeatureStrings.settingsPages(l10n.language) }
    private var dockPreviewInstalled: Bool { AppFeature.dockPreview.isAvailable }
    private var dockPreviewEngaged: Bool { dockPreviewInstalled && dockPreviewEnabled }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dockPreviewCard
                    .settingsSectionAnchor(.dock, cornerRadius: 16)
                if needsAccessibility, !permissions.accessibility {
                    SettingsCard(title: l10n.s.permissionRequired) {
                        PermissionRow(kind: .accessibility)
                    }
                }
                if dockPreviewEngaged, !permissions.screenRecording {
                    SettingsCard {
                        PermissionRow(kind: .screenRecording)
                    }
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
    }

    private var dockPreviewCard: some View {
        SettingsCard(title: l10n.s.dockPreviewName, headerAccessory: {
            Button { showingDockInfo.toggle() } label: { Image(systemName: "info.circle") }
                .buttonStyle(.plain)
                .accessibilityLabel(pages.dockDescription)
                .popover(isPresented: $showingDockInfo) {
                    Text(pages.dockDescription).font(.callout).padding(16).frame(width: 320)
                }
        }) {
            SettingsRow(symbol: "dock.rectangle", title: l10n.s.dockPreviewEnable, caption: dockPreviewCaption) {
                PermissionGatedToggle(l10n.s.dockPreviewEnable, isOn: Binding(
                    get: { dockPreviewEngaged },
                    set: { enabled in
                        dockPreviewEnabled = enabled
                        FeatureRuntime.shared.setAvailable([.dockPreview], enabled)
                        DockPreviewService.shared.syncWithPreferences()
                    }
                ), requiring: [.accessibility, .screenRecording])
                    .labelsHidden()
            }
            WindowPreviewExclusionsList(key: DefaultsKey.windowPreviewExcludedApps)
                .padding(.leading, settingsRowTextInset)
                .disabled(!dockPreviewEngaged)
                .opacity(dockPreviewEngaged ? 1 : 0.55)
            Group {
                SettingsRow(symbol: "rectangle.3.group", title: l10n.s.switcherCurrentSpaceOnly,
                            caption: l10n.s.dockPreviewCurrentSpaceOnlyCaption) {
                    Toggle(l10n.s.switcherCurrentSpaceOnly, isOn: $dockPreviewCurrentSpaceOnly)
                        .labelsHidden()
                        .onChange(of: dockPreviewCurrentSpaceOnly) { _, _ in
                            DockPreviewService.shared.syncWithPreferences()
                        }
                }
                SettingsRow(symbol: "timer", title: l10n.s.dockPreviewOpenDelay,
                            caption: l10n.s.dockPreviewOpenDelayCaption) {
                    HStack(spacing: 6) {
                        TextField("", value: dockPreviewOpenDelayBinding,
                                  formatter: Self.dockPreviewOpenDelayFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 64)
                        Stepper("", value: dockPreviewOpenDelayBinding,
                                in: DockPreviewSupport.openDelayMillisecondsRange,
                                step: 50)
                            .labelsHidden()
                        Text(verbatim: "ms")
                            .foregroundStyle(.secondary)
                    }
                }
                if !dockPreviewBackgroundIsGlass {
                    SettingsRow(symbol: "circle.lefthalf.filled", title: l10n.s.dockPreviewBackgroundOpacity,
                                caption: l10n.s.dockPreviewBackgroundOpacityCaption) {
                        SettingsValueSlider(title: l10n.s.dockPreviewBackgroundOpacity,
                            value: dockPreviewBackgroundOpacityBinding,
                            range: DockPreviewSupport.backgroundOpacityRange, step: 0.05,
                            readout: "\(dockPreviewBackgroundOpacityPercent)%", usesSystemAppearance: true)
                            .frame(width: 140)
                    }
                }
                SettingsRow(symbol: "xmark.circle", title: l10n.s.dockPreviewQuitAppOnClose,
                            caption: l10n.s.dockPreviewQuitAppOnCloseCaption) {
                    Toggle(l10n.s.dockPreviewQuitAppOnClose, isOn: $dockPreviewQuitAppOnClose).labelsHidden()
                }
                Group {
                    SettingsRow(symbol: "dock.rectangle", title: l10n.s.dockPreviewKeepDockVisible,
                                experimentalBadge: FeatureStrings.hub(l10n.language).experimentalBadge,
                                caption: l10n.s.dockPreviewKeepDockVisibleCaption) {
                        Toggle(l10n.s.dockPreviewKeepDockVisible, isOn: $dockPreviewKeepDockVisible)
                            .labelsHidden()
                            .disabled(!DockAutohideHold.isSupported && !dockPreviewKeepDockVisible)
                            .onChange(of: dockPreviewKeepDockVisible) { _, _ in
                                dockPreview.syncWithPreferences()
                            }
                    }
                    SettingsRow(symbol: "clock.arrow.circlepath", title: l10n.s.dockPreviewOrderByCreation,
                                caption: l10n.s.dockPreviewOrderByCreationCaption) {
                        Toggle(l10n.s.dockPreviewOrderByCreation, isOn: $dockPreviewOrderByCreation).labelsHidden()
                    }
                }
                Divider()
                WindowPreviewsCard(sizeKey: DefaultsKey.previewSize,
                                   excludedAppsKey: DefaultsKey.windowPreviewExcludedApps,
                                   embedded: true, showsExclusions: false)
            }
            .disabled(!dockPreviewInstalled)
            .opacity(dockPreviewInstalled ? 1 : 0.55)
            if AppFeature.dockClick.isPresentInControls() {
                Divider()
                DockClickSettings()
                    .settingsSectionAnchor(.dockClick, cornerRadius: 16)
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

    private var dockPreviewCaption: String {
        guard dockPreviewEnabled else { return l10n.s.dockPreviewEnableCaption }
        if !permissions.accessibility { return "\(l10n.s.permissionRequired): \(l10n.s.permissionAccessibility)" }
        if !permissions.screenRecording { return "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)" }
        switch dockPreview.blockedReason {
        case .dockUnavailable: return l10n.s.dockPreviewDockUnavailable
        default:
            return l10n.s.dockPreviewEnableCaption
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

    private var dockPreviewOpenDelayBinding: Binding<Int> {
        Binding(
            get: { DockPreviewSupport.sanitizedOpenDelay(milliseconds: dockPreviewOpenDelay) },
            set: { dockPreviewOpenDelay = DockPreviewSupport.sanitizedOpenDelay(milliseconds: $0) }
        )
    }

    /// Bounded here as well as in the binding: the field rejects an out-of-range
    /// number as it is typed rather than silently snapping it afterwards.
    private static let dockPreviewOpenDelayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: DockPreviewSupport.openDelayMillisecondsRange.lowerBound)
        formatter.maximum = NSNumber(value: DockPreviewSupport.openDelayMillisecondsRange.upperBound)
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}

