// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct WindowLayoutSettings: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var service = WindowLayoutService.shared
    @AppStorage(DefaultsKey.windowMaximizeEnabled) var maximizeEnabled = false
    @AppStorage(DefaultsKey.windowEdgeSnapEnabled) var edgeSnapEnabled = false
    @AppStorage(DefaultsKey.windowEdgeSnapDisabledZones) var edgeSnapDisabledZones = ""
    @AppStorage(DefaultsKey.windowEdgeSnapZoneActions) var edgeSnapZoneActions = ""
    @AppStorage(DefaultsKey.windowGestureEnabled) var gestureEnabled = false
    @AppStorage(DefaultsKey.windowGestureModifiers) var gestureModifiers = WindowGestureSupport.defaultModifierStorageValue
    @AppStorage(DefaultsKey.windowGestureRaiseWindow) var gestureRaiseWindow = false
    @AppStorage(DefaultsKey.windowLayoutWindowGap) var windowGap = 0
    @AppStorage(DefaultsKey.windowLayoutScreenGap) var screenGap = 0
    @AppStorage(DefaultsKey.windowReserveStageManagerSpace) var reserveStageManagerSpace = false
    @AppStorage(DefaultsKey.spacesOrderEnabled) var spacesOrderEnabled = false
    @AppStorage(DefaultsKey.autoQuitEnabled) var autoQuitEnabled = false
    @State var systemTilingEnabled = WindowEdgeSnapSupport.isSystemTilingEnabled

    var text: WindowLayoutFeatureStrings {
        FeatureStrings.windowLayout(l10n.language)
    }

    var stageManagerText: WindowStageManagerStrings {
        WindowStageManagerStrings.localized(l10n.language)
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
        .onAppear { refreshSystemTilingState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSystemTilingState()
        }
        .settingsExpansionAnimation(value: [systemTilingEnabled, edgeSnapEnabled, permissions.accessibility, maximizeEnabled, gestureEnabled, windowLayoutInstalled, autoQuitEnabled, reserveStageManagerSpace])
    }

    var windowsAndSpaces: some View {
        SettingsCard(symbol: "appwindow.swipe.rectangle", title: SettingsWindowGroupStrings.text(l10n.language)) {
            VStack(alignment: .leading, spacing: 14) {
                if AppFeature.windowMaximizer.isPresentInControls() {
                    VStack(alignment: .leading, spacing: 13) {
                        SettingsControlRow(title: l10n.s.windowMaximizeName,
                                           caption: l10n.s.windowMaximizeCaption) {
                            PermissionGatedToggle(l10n.s.windowMaximizeName, isOn: $maximizeEnabled).labelsHidden()
                                .onChange(of: maximizeEnabled) { _, _ in FeatureRuntime.shared.sync([.windowMaximizer]) }
                        }
                        if maximizeEnabled {
                            WindowMaximizerExclusionsList()
                        }
                    }
                    .settingsSectionAnchor(.windowMaximizer, cornerRadius: 16)
                    Divider()
                }
                moveAndResizeDragging
                Divider()
                DockQuitOnCloseSettings()
                if AppFeature.spacesOrder.isPresentInControls() {
                    Divider()
                    SettingsControlRow(title: l10n.s.spacesOrderName,
                                       caption: l10n.s.spacesOrderCaption) {
                        Toggle(l10n.s.spacesOrderName, isOn: $spacesOrderEnabled).labelsHidden()
                            .onChange(of: spacesOrderEnabled) { _, _ in FeatureRuntime.shared.sync([.spacesOrder]) }
                    }
                    .settingsSectionAnchor(.spacesOrder, cornerRadius: 16)
                }
            }
            .padding(.leading, settingsRowTextInset)
        }
    }

    var moveAndResizeDragging: some View {
        VStack(alignment: .leading, spacing: 13) {
            SettingsControlRow(title: text.gestureEnable,
                               caption: text.gestureCaption) {
                PermissionGatedToggle(text.gestureEnable, isOn: $gestureEnabled)
                    .labelsHidden()
                    .onChange(of: gestureEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: DefaultsKey.windowGestureEnabled)
                        WindowLayoutService.shared.syncWithPreferences()
                    }
            }
            if gestureEnabled {
                VStack(alignment: .leading, spacing: 13) {
                    WindowGestureModifierPicker(storageValue: $gestureModifiers,
                                                title: text.gestureModifiers)
                        .onChange(of: gestureModifiers) { _, _ in
                            WindowLayoutService.shared.syncWithPreferences()
                        }
                    WindowGestureHints(modifierStorage: gestureModifiers,
                                       moveText: text.gestureMove,
                                       resizeText: text.gestureResize)
                    SettingsToggleRow(title: text.gestureRaiseWindow, isOn: $gestureRaiseWindow)
                    // Gestures honour the same ignored apps; with arrangement
                    // off, its card is folded, so the list shows here.
                    if !windowLayoutInstalled {
                        WindowLayoutIgnoredAppsList()
                    }
                }
            }
        }
    }

    var snappingCard: some View {
        SettingsCard(symbol: "rectangle.3.group", title: text.gestureSection, headerSpacing: windowLayoutInstalled ? 14 : 0, headerAccessory: {
            PermissionGatedToggle(text.gestureSection, isOn: Binding(
                get: { windowLayoutInstalled },
                set: { enabled in
                    FeatureRuntime.shared.setAvailable([.windowLayout], enabled)
                    WindowLayoutService.shared.syncWithPreferences()
                }
            ))
            .labelsHidden()
        }) {
            if windowLayoutInstalled {
                VStack(alignment: .leading, spacing: 16) {
                    WindowLayoutIgnoredAppsList()
                    gapPicker(text.windowGap, selection: $windowGap)
                    gapPicker(text.screenGap, selection: $screenGap)
                    SettingsToggleRow(title: stageManagerText.title,
                                      caption: stageManagerText.caption,
                                      isOn: $reserveStageManagerSpace)
                    Divider()
                    edgeSnapControls
                }
                .padding(.leading, settingsRowTextInset)
                .toggleStyle(TrailingSwitchToggleStyle())

                Divider()
                    .padding(.leading, settingsRowTextInset)

                Button {
                    SettingsRouter.shared.request(FeatureSettingsDestination(.windowLayoutShortcuts))
                } label: {
                    HStack(spacing: 12) {
                        Text(WindowLayoutFeatureStrings.manageShortcuts(l10n.language))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, settingsRowTextInset)
            }
        }
    }
}
