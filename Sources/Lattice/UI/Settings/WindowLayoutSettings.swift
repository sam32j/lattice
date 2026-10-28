// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct WindowLayoutSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var service = WindowLayoutService.shared
    @AppStorage(DefaultsKey.windowMaximizeEnabled) var maximizeEnabled = false
    @ObservedObject var pointerDisplay = PointerDisplayService.shared
    @AppStorage(DefaultsKey.pointerDisplayEnabled) var pointerDisplayEnabled = false
    @AppStorage(DefaultsKey.windowDirectionalEnabled) var directionalEnabled = false
    @AppStorage(DefaultsKey.windowDirectionalShortcut) var directionalShortcutRaw = GlobalShortcut.windowDirectionalDefault.storageValue
    @AppStorage(DefaultsKey.windowEdgeSnapEnabled) var edgeSnapEnabled = false
    @AppStorage(DefaultsKey.windowEdgeSnapDisabledZones) var edgeSnapDisabledZones = ""
    @AppStorage(DefaultsKey.windowEdgeSnapZoneActions) var edgeSnapZoneActions = ""
    @AppStorage(DefaultsKey.windowGestureEnabled) var gestureEnabled = false
    @AppStorage(DefaultsKey.windowGestureModifiers) var gestureModifiers = WindowGestureSupport.defaultModifierStorageValue
    @AppStorage(DefaultsKey.windowGestureRaiseWindow) var gestureRaiseWindow = false
    @AppStorage(DefaultsKey.windowLayoutWindowGap) var windowGap = 0
    @AppStorage(DefaultsKey.windowLayoutScreenGap) var screenGap = 0
    @AppStorage(DefaultsKey.windowLayoutMarginPercent) var marginPercent = WindowLayoutMargin.defaultPercent
    @AppStorage(DefaultsKey.windowLayoutSideRepeatCyclesThirds) var sideRepeatCyclesThirds = false
    @AppStorage(DefaultsKey.spacesOrderEnabled) var spacesOrderEnabled = false
    @AppStorage(DefaultsKey.windowLayoutShortcutMarginMaximize) var marginShortcutRaw = WindowLayoutAction.marginMaximize.defaultShortcut?.storageValue ?? WindowLayoutAction.clearedShortcutStorageValue
    @State var directionalError: String?
    @State var systemTilingEnabled = WindowEdgeSnapSupport.isSystemTilingEnabled
    @State var conflictAlert: ShortcutConflictAlert?
    var text: WindowLayoutFeatureStrings {
        FeatureStrings.windowLayout(l10n.language)
    }

    var windowLayoutInstalled: Bool {
        AppFeature.windowLayout.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                windowsAndSpaces
                snappingCard
                if !permissions.accessibility {
                    SettingsCard(title: l10n.s.permissionRequired) { PermissionRow(kind: .accessibility) }
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .shortcutConflictAlert($conflictAlert)
        .onAppear { refreshSystemTilingState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSystemTilingState()
        }
        .settingsExpansionAnimation(value: [systemTilingEnabled, edgeSnapEnabled, permissions.accessibility])
    }

    var windowsAndSpaces: some View {
        SettingsCard(title: SettingsWindowGroupStrings.text(l10n.language)) {
            if AppFeature.windowMaximizer.isPresentInControls() {
                VStack(alignment: .leading, spacing: 13) {
                    SettingsRow(symbol: "arrow.up.left.and.arrow.down.right", title: l10n.s.windowMaximizeName,
                                caption: l10n.s.windowMaximizeCaption) {
                        PermissionGatedToggle(l10n.s.windowMaximizeName, isOn: $maximizeEnabled).labelsHidden()
                            .onChange(of: maximizeEnabled) { _, _ in FeatureRuntime.shared.sync([.windowMaximizer]) }
                    }
                    WindowMaximizerExclusionsList()
                        .padding(.leading, settingsRowTextInset)
                        .disabled(!maximizeEnabled)
                        .opacity(maximizeEnabled ? 1 : 0.55)
                }
                .settingsSectionAnchor(.windowMaximizer, cornerRadius: 16)
                Divider()
            }
            DockQuitOnCloseSettings()
            if AppFeature.spacesOrder.isPresentInControls() {
                Divider()
                SettingsRow(symbol: "square.stack.3d.up", title: l10n.s.spacesOrderName,
                            caption: l10n.s.spacesOrderCaption) {
                    Toggle(l10n.s.spacesOrderName, isOn: $spacesOrderEnabled).labelsHidden()
                        .onChange(of: spacesOrderEnabled) { _, _ in FeatureRuntime.shared.sync([.spacesOrder]) }
                }
                .settingsSectionAnchor(.spacesOrder, cornerRadius: 16)
            }
        }
    }

    var snappingCard: some View {
        SettingsCard(title: text.gestureSection) {
            SettingsRow(symbol: "rectangle.3.group", title: text.enable, caption: text.caption) {
                PermissionGatedToggle(text.enable, isOn: Binding(
                    get: { windowLayoutInstalled },
                    set: { enabled in
                        FeatureRuntime.shared.setAvailable([.windowLayout], enabled)
                        WindowLayoutService.shared.syncWithPreferences()
                    }
                ))
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 16) {
                WindowLayoutIgnoredAppsList()
                    .padding(.leading, settingsRowTextInset)
                snappingControls
            }
            .toggleStyle(TrailingSwitchToggleStyle())
            .disabled(!windowLayoutInstalled)
            .opacity(windowLayoutInstalled ? 1 : 0.55)
        }
    }

}
