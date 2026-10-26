// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Mouse and trackpad controls grouped by scrolling, pointer and buttons.
struct MouseSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var inverter = ScrollInverter.shared
    @ObservedObject var smoothScroll = SmoothScrollService.shared
    @ObservedObject var mouseNavigation = MouseNavigationService.shared
    @ObservedObject var middleClick = MiddleClickService.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(DefaultsKey.scrollInverterEnabled) var invertVertical = false
    @AppStorage(DefaultsKey.scrollInverterHorizontalEnabled) var invertHorizontal = false
    @AppStorage(DefaultsKey.scrollHorizontalEnabled) var horizontalScrollEnabled = false
    @AppStorage(DefaultsKey.scrollHorizontalModifier) var horizontalScrollModifier =
        ScrollHorizontalModifier.shift
    @AppStorage(DefaultsKey.focusFollowsMouseEnabled) var focusFollowsMouseEnabled = false
    @AppStorage(DefaultsKey.focusFollowsMouseRaise) var focusFollowsMouseRaise = true
    @AppStorage(DefaultsKey.focusFollowsMouseWaitForStop) var focusFollowsMouseWaitForStop = true
    @AppStorage(DefaultsKey.focusFollowsMouseDelay) var focusFollowsMouseDelay =
        FocusFollowsMouseSupport.defaultDelayMilliseconds
    @AppStorage(DefaultsKey.smoothScrollEnabled) var smoothScrollEnabled = false
    @AppStorage(DefaultsKey.smoothScrollStep) var smoothScrollStep = SmoothScrollSupport.defaultStep
    @AppStorage(DefaultsKey.mouseAccelerationDisabled) var mouseAccelerationDisabled = false
    @AppStorage(DefaultsKey.linearScrollEnabled) var linearScrollEnabled = false
    @AppStorage(DefaultsKey.linearScrollLines) var linearScrollLines =
        ScrollWheelSupport.defaultLinesPerNotch
    @AppStorage(DefaultsKey.smoothScrollResponse) var smoothScrollResponse =
        SmoothScrollSupport.defaultResponse
    @AppStorage(DefaultsKey.smoothScrollCoast) var smoothScrollCoast =
        SmoothScrollSupport.defaultCoast
    @AppStorage(DefaultsKey.mouseNavigationEnabled) var mouseNavigationEnabled = false
    @AppStorage(DefaultsKey.mouseButtonShortcutsEnabled) var mouseButtonShortcutsEnabled = false
    @AppStorage(DefaultsKey.mouseSpacesGestureEnabled) var spacesEnabled = false
    @AppStorage(DefaultsKey.middleClickEnabled) var middleClickEnabled = false
    @AppStorage(DefaultsKey.middleClickTapFingers) var middleClickTapFingers = 0
    @AppStorage(DefaultsKey.mouseClickDebounceEnabled) var mouseClickDebounceEnabled = false
    @AppStorage(DefaultsKey.mouseClickDebounceWindowMs) var mouseClickDebounceWindow =
        Defaults.defaultMouseClickDebounceWindowMs

    var mouseClickDebounceText: MouseClickDebounceStrings {
        FeatureStrings.mouseClickDebounce(l10n.language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mouseScrollingCard
                mouseClicksCard
                mouseButtonsCard
                middleClickCard
                    .settingsSectionAnchor(.middleClick, cornerRadius: 16)
                if accessibilityNoteVisible {
                    SettingsCard(title: l10n.s.permissionRequired) {
                        PermissionRow(kind: .accessibility)
                    }
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .onAppear {
            MiddleClickService.shared.refreshDragGestureConflict()
        }
        .settingsExpansionAnimation(value: [horizontalScrollEnabled, smoothScrollEnabled, linearScrollEnabled,
            focusFollowsMouseEnabled, focusFollowsMouseRaise, mouseNavigationEnabled, mouseButtonShortcutsEnabled,
            spacesEnabled, mouseClickDebounceEnabled, middleClickEnabled, accessibilityNoteVisible])
    }



    var mouseScrollingCard: some View {
        SettingsCard(title: InputSettingsStrings.text(.mouseScrolling, l10n.language)) {
            scrollControls.settingsSectionAnchor(.scrollDirection, cornerRadius: 12)
            Divider()
            smoothScrollControls.settingsSectionAnchor(.smoothScroll, cornerRadius: 12)
            Divider()
            linearScrollControls.settingsSectionAnchor(.linearScroll, cornerRadius: 12)
            Divider()
            accelerationControls.settingsSectionAnchor(.mouseAcceleration, cornerRadius: 12)
        }
    }

    var mouseClicksCard: some View {
        SettingsCard(title: InputSettingsStrings.text(.mouseClicks, l10n.language)) {
            focusFollowsMouseControls.settingsSectionAnchor(.focusFollowsMouse, cornerRadius: 12)
            Divider()
            clickFilterControls.settingsSectionAnchor(.mouseClickDebounce, cornerRadius: 12)
        }
    }

    var mouseButtonsCard: some View {
        SettingsCard(title: InputSettingsStrings.text(.mouseButtons, l10n.language)) {
            navigationControls.settingsSectionAnchor(.mouseNavigation, cornerRadius: 12)
            Divider()
            MouseButtonShortcutsSection()
        }
    }

    // MARK: - State

    var accessibilityNoteVisible: Bool {
        let anyEngaged = scrollDirectionEnabled
            || focusFollowsMouseEnabled
            || smoothScrollEnabled
            || linearScrollEnabled
            || mouseNavigationEnabled
            || ((mouseButtonShortcutsEnabled || spacesEnabled)
                && AppFeature.mouseButtonShortcuts.isAvailable)
            || mouseClickDebounceEnabled
            || middleClickEnabled
        return anyEngaged && !permissions.accessibility
    }

    var scrollInversionEnabled: Bool {
        invertVertical || invertHorizontal
    }

    var scrollDirectionEnabled: Bool {
        scrollInversionEnabled || horizontalScrollEnabled
    }

    var smoothScrollStepBinding: Binding<Double> {
        Binding(
            get: { Double(SmoothScrollSupport.sanitizedStep(smoothScrollStep)) },
            set: { smoothScrollStep = Int($0) }
        )
    }

    var smoothScrollResponseBinding: Binding<Double> {
        Binding(
            get: { Double(SmoothScrollSupport.sanitizedResponse(smoothScrollResponse)) },
            set: { smoothScrollResponse = Int($0) }
        )
    }

    var smoothScrollCoastBinding: Binding<Double> {
        Binding(
            get: { Double(SmoothScrollSupport.sanitizedCoast(smoothScrollCoast)) },
            set: { smoothScrollCoast = Int($0) }
        )
    }

    var linearScrollLinesBinding: Binding<Double> {
        Binding(
            get: { Double(ScrollWheelSupport.sanitizedLinesPerNotch(linearScrollLines)) },
            set: { linearScrollLines = Int($0) }
        )
    }

    var focusFollowsMouseDelayBinding: Binding<Double> {
        Binding(
            get: { Double(FocusFollowsMouseSupport.sanitizedDelay(focusFollowsMouseDelay)) },
            set: {
                focusFollowsMouseDelay = Int($0)
                FocusFollowsMouseService.shared.preferencesDidChange()
            }
        )
    }

    var mouseClickDebounceWindowBinding: Binding<Int> {
        Binding(
            get: { Defaults.sanitizedMouseClickDebounceWindow(mouseClickDebounceWindow) },
            set: {
                mouseClickDebounceWindow = Defaults.sanitizedMouseClickDebounceWindow($0)
                MouseClickDebounceService.shared.syncWithPreferences()
            }
        )
    }}
