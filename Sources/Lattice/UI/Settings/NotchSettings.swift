// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import EventKit

struct NotchSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var notch = NotchService.shared
    @ObservedObject var router = SettingsRouter.shared
    @AppStorage(DefaultsKey.notchGesturesEnabled) var gesturesEnabled = true
    @AppStorage(DefaultsKey.notchKeyboardLight) var keyboardLight = true
    @AppStorage(DefaultsKey.notchNotificationsEnabled) var notificationsEnabled = true
    @AppStorage(DefaultsKey.notchDismissNativeNotifications) var dismissNativeNotifications = false
    @AppStorage(DefaultsKey.notchTimerEnabled) var timerEnabled = true
    @AppStorage(DefaultsKey.notchTimerSoundEnabled) var timerSoundEnabled = true
    @AppStorage(DefaultsKey.notchHideTimerCountdown) var hideTimerCountdown = false
    @AppStorage(DefaultsKey.notchCameraEnabled) var cameraEnabled = true
    @AppStorage(DefaultsKey.notchAccessoriesEnabled) var accessoriesEnabled = true
    @AppStorage(DefaultsKey.notchCalendarEnabled) var calendarEnabled = true
    @AppStorage(DefaultsKey.notchCalendarCountdown) var calendarCountdown = false
    @AppStorage(DefaultsKey.notchCalendarTimeLeft) var calendarTimeLeft = false
    @AppStorage(DefaultsKey.notchCalendarWeekNumbers) var calendarWeekNumbers = false
    @AppStorage(DefaultsKey.notchAgentsEnabled) var agentsEnabled = false
    @AppStorage(DefaultsKey.notchWatchEnabled) var watchEnabled = true
    @AppStorage(DefaultsKey.notchLyricsEnabled) var lyricsEnabled = true
    @AppStorage(DefaultsKey.notchLyricsOnline) var lyricsOnline = false
    @AppStorage(DefaultsKey.notchBrowserCovers) var browserCovers = false
    @AppStorage(DefaultsKey.notchQueueEnabled) var queueEnabled = true
    @AppStorage(DefaultsKey.notchLiveEqualizer) var liveEqualizer = false
    @AppStorage(DefaultsKey.notchEnabled) var enabled = false
    @AppStorage(DefaultsKey.notchMascotEnabled) var mascotEnabled = false
    @AppStorage(DefaultsKey.notchMascotHidesWhenIdle) var mascotHidesWhenIdle = true
    @AppStorage(DefaultsKey.notchMascotStyle) var mascotStyle = NotchMascotStyle.minimal.rawValue
    @AppStorage(DefaultsKey.notchMascotShape) var mascotShape = NotchMascotShape.ball.rawValue
    @AppStorage(DefaultsKey.notchMascotPalette) var mascotPalette = NotchMascotPalette.pearl.rawValue
    @AppStorage(DefaultsKey.notchMascotSide) var mascotSide = NotchMascotSide.left.rawValue
    @AppStorage(DefaultsKey.notchDisplay) var display = NotchDisplay.automatic.rawValue
    @AppStorage(DefaultsKey.notchSilhouette) var silhouette = NotchSilhouette.capsule.rawValue
    @AppStorage(DefaultsKey.notchOpenOnHover) var hover = false
    @AppStorage(DefaultsKey.notchShortcutEnabled) var shortcutEnabled = false
    @AppStorage(DefaultsKey.notchHideInFullscreen) var hideInFullscreen = false
    @AppStorage(DefaultsKey.notchHideUntilHover) var hideUntilHover = false
    @AppStorage(DefaultsKey.notchHiddenShowsActivity) var hiddenShowsActivity = false
    @AppStorage(DefaultsKey.notchCoversMenus) var coversMenus = true
    @AppStorage(DefaultsKey.notchHoverDelay) var hoverDelay = NotchSupport.defaultHoverDelay
    @AppStorage(DefaultsKey.notchCloseDelay) var closeDelay = NotchSupport.defaultCloseDelay
    @AppStorage(DefaultsKey.notchReturnHome) var returnHome = false
    @AppStorage(DefaultsKey.notchHomeModule) var homeModule = NotchModule.controls.rawValue
    @AppStorage(DefaultsKey.notchOpensActivity) var opensActivity = true
    @AppStorage(DefaultsKey.notchHiddenModules) var hidden = ""
    @AppStorage(DefaultsKey.notchModuleOrder) var order = ""
    @AppStorage(DefaultsKey.notchVolume) var volume = true
    @AppStorage(DefaultsKey.notchInputSource) var inputSource = true
    @AppStorage(DefaultsKey.notchMicrophone) var microphone = true
    @AppStorage(DefaultsKey.notchBrightness) var brightness = true
    @AppStorage(DefaultsKey.notchBattery) var battery = true
    @AppStorage(DefaultsKey.notchClipboard) var clipboard = true
    @AppStorage(DefaultsKey.notchClipboardWindow) var clipboardWindow = true
    @AppStorage(DefaultsKey.notchSnippetsWindow) var snippetsWindow = true
    @AppStorage(DefaultsKey.notchClipboardCardSize) var clipboardCardSize = NotchClipboardCardSize.comfortable.rawValue
    @AppStorage(DefaultsKey.screenshotDefaultAction) var captureAction = ""
    @AppStorage(DefaultsKey.notchCapture) var capture = true
    @AppStorage(DefaultsKey.notchTrackChange) var trackChange = true
    @AppStorage(DefaultsKey.notchShowPlayingMusic) var showPlayingMusic = true
    @AppStorage(DefaultsKey.notchIncludeOtherPlayers) var includeOtherPlayers = true
    @AppStorage(DefaultsKey.notchPreferredPlayer) var preferredPlayer = NotchPreferredPlayer.automatic
    @AppStorage(DefaultsKey.notchIdleContent) var idle = NotchIdleContent.music.rawValue
    @AppStorage(DefaultsKey.notchLowBatteryTint) var lowBatteryTint = false
    @AppStorage(DefaultsKey.notchLowBatteryThreshold) var lowBatteryThreshold = NotchSupport.defaultLowBatteryThreshold
    @AppStorage(DefaultsKey.notchLowBatteryEarly) var earlyBatteryWarning = false
    @AppStorage(DefaultsKey.notchLowBatteryEarlyThreshold) var earlyBatteryThreshold = NotchSupport.defaultEarlyBatteryThreshold
    @AppStorage(DefaultsKey.notchLowBatteryMenuBar) var lowBatteryMenuBar = true
    @AppStorage(DefaultsKey.notchHiddenControls) var hiddenControls = NotchControlItem.defaultHidden
    @AppStorage(DefaultsKey.notchControlOrder) var controlOrder = ""
    @AppStorage(DefaultsKey.notchShowInCaptures) var showInCaptures = true
    @AppStorage(DefaultsKey.notchLockScreen) var lockScreen = false
    @AppStorage(DefaultsKey.notchSize) var size = NotchSize.spacious.rawValue
    @AppStorage(DefaultsKey.notchHapticFeedback) var hapticFeedback = true
    @AppStorage(DefaultsKey.notchShelf) var shelfWindow = true
    @AppStorage(DefaultsKey.notchDragReveal) var dragReveal = true
    @AppStorage(DefaultsKey.notchAppPanel) var appPanel = false
    @AppStorage(DefaultsKey.notchKeepAwakeActivity) var keepAwakeActivity = false
    @AppStorage(DefaultsKey.notchScratchpad) var scratchpad = true
    @AppStorage(DefaultsKey.brightnessControlEnabled) var brightnessControlEnabled = false
    @AppStorage(DefaultsKey.clipboardHistoryEnabled) var clipboardHistoryEnabled = false
    @AppStorage(DefaultsKey.notchHoverExpands) var hoverExpand = true
    @AppStorage(DefaultsKey.notchQuickAccessLayout) var accessData = Data()
    @State var tab = NotchSettingsTab.layout
    @State var selectedModule = NotchModule.controls
    @State var contentSelection: NotchContentDestination?
    @State var draggingModule: NotchModule?
    @State var draggingControl: NotchControlItem?
    @State var preferredPlayers: [NotchPreferredPlayer.Choice]?
    @State var scrollTarget: String?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }

    init(initialTab: NotchSettingsTab = .layout, initialContent: NotchContentDestination? = nil) {
        _tab = State(initialValue: initialTab)
        _contentSelection = State(initialValue: initialContent)
        if case .module(let module) = initialContent { _selectedModule = State(initialValue: module) }
    }

    @ViewBuilder
    var body: some View {
        Group {
            if let selection = contentSelection {
                contentDetailView(selection: selection)
            } else {
                combinedPageView
            }
        }
        .onChange(of: configuration) { _, _ in sync() }
        .onChange(of: browserCovers) { _, _ in NotchMusicService.shared.syncBrowserCovers() }
        .onChange(of: accessData) { _, _ in NotchService.shared.syncWithPreferences() }
        .onChange(of: tab) { _, _ in draggingModule = nil; draggingControl = nil }
        .onAppear(perform: consumeTabHint)
        .onChange(of: router.notchSettingsTab) { _, _ in consumeTabHint() }
        .onAppear(perform: consumeModuleHint)
        .onChange(of: router.notchModule) { _, _ in consumeModuleHint() }
        .onAppear(perform: consumeCompanionHint)
        .onChange(of: router.notchCompanion) { _, _ in consumeCompanionHint() }
        .settingsExpansionAnimation(value: [hover, hideUntilHover, hoverExpand, shortcutEnabled, lowBatteryTint,
            earlyBatteryWarning, lyricsEnabled, shelfWindow, clipboardWindow, snippetsWindow, accessoriesEnabled,
            permissions.accessibility])
        .settingsExpansionAnimation(value: [idle, size, silhouette, display])
        .settingsExpansionAnimation(value: [enabled, hiddenShowsActivity, gesturesEnabled, notificationsEnabled,
                                            volume, brightness, keyboardLight, watchEnabled])
        .settingsExpansionAnimation(value: permissions.calendarAccess == .fullAccess)
        .settingsExpansionAnimation(value: permissions.camera == .granted)
    }

    func consumeTabHint() {
        guard let requested = router.notchSettingsTab else { return }
        router.notchSettingsTab = nil
        tab = requested == "behavior" ? .behavior : .activity
        contentSelection = nil
        scrollTarget = requested
    }

    /// The companion's own settings were asked for; the hint is one-shot.
    func consumeCompanionHint() {
        guard router.notchCompanion else { return }
        router.notchCompanion = false
        router.request(FeatureSettingsDestination(.notchCompanion))
    }

    @ViewBuilder
    var combinedPageView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsCard {
                        SettingsRow(symbol: AppFeature.notch.symbolName, title: text.enable,
                                    experimentalBadge: FeatureStrings.hub(l10n.language).experimentalBadge) {
                            PermissionGatedToggle(text.enable, isOn: islandFeatureBinding(.notch, value: $enabled))
                                .labelsHidden().toggleStyle(.switch)
                        }
                        let labels = FeatureStrings.notchLiveActivitySettings(l10n.language)
                        ShortcutPreferenceRow(role: .notch, label: labels.openWithShortcut, symbolName: nil) {
                            NotchService.shared.syncWithPreferences()
                        }
                        .padding(.leading, settingsRowTextInset)
                        .disabled(!enabled)
                        if notch.shortcutRegistrationFailed {
                            Text(l10n.s.shortcutUnavailable)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.leading, settingsRowTextInset)
                        }
                        SettingsControlRow(title: labels.showOn) {
                            Picker(labels.showOn, selection: $display) {
                                Text(text.automatic).tag(NotchDisplay.automatic.rawValue)
                                if PowerSampler.hasInternalBattery {
                                    Text(text.builtIn).tag(NotchDisplay.builtIn.rawValue)
                                }
                                Text(text.mainDisplay).tag(NotchDisplay.main.rawValue)
                                Text(text.followPointer).tag(NotchDisplay.pointer.rawValue)
                                Text(text.allDisplays).tag(NotchDisplay.all.rawValue)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        .padding(.leading, settingsRowTextInset)
                        .disabled(!enabled)
                        SettingsRow(symbol: "arrow.down.backward.and.arrow.up.forward.rectangle", title: labels.dynamicIslandSize) {
                            Picker(labels.dynamicIslandSize, selection: Binding(get: {
                                size == NotchSize.compact.rawValue ? NotchSize.compact.rawValue : NotchSize.spacious.rawValue
                            }, set: { size = $0 })) {
                                Text(text.compact).tag(NotchSize.compact.rawValue)
                                Text(text.spacious).tag(NotchSize.spacious.rawValue)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .fixedSize()
                        }
                        .disabled(!enabled)
                        switchRow("hand.draw", labels.useScrollGestures,
                                  isOn: islandFeatureBinding(.notchGestures, value: $gesturesEnabled))
                            .disabled(!enabled)
                        if gesturesEnabled {
                            SettingsToggleRow(title: labels.turnOnHapticFeedback, isOn: $hapticFeedback)
                                .padding(.leading, settingsRowTextInset)
                                .disabled(!enabled)
                        }
                        switchRow("camera.viewfinder", labels.showInScreenshots, isOn: $showInCaptures)
                            .disabled(!enabled)
                    }
                    if enabled, AppFeature.notch.isAvailable, !(hover && hideUntilHover && !hiddenShowsActivity), !notch.geometry.isNotched, !permissions.accessibility {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(text.menuBarAccessHint)
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            PermissionRow(kind: .accessibility)
                        }
                    }

                    VStack(alignment: .leading, spacing: 28) {
                        layoutPage
                            .id("layout")

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(editor.content).font(.title3.weight(.semibold))
                            sectionList
                        }
                        .id("content")

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(editor.activity).font(.title3.weight(.semibold))
                            activityPage
                        }
                        .id("activity")

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(editor.behavior).font(.title3.weight(.semibold))
                            behaviorPage
                        }
                        .id("behavior")
                    }
                    .disabled(!enabled)
                    .opacity(enabled ? 1.0 : 0.5)
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(22)
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                scrollTarget = nil
                withAnimation {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
    }

    /// A section of the island can ask for its own options; the hint is one-shot.
    func consumeModuleHint() {
        guard let module = router.notchModule else { return }
        router.notchModule = nil
        router.request(FeatureSettingsDestination(.notchWidget(module)))
    }

    func sync() {
        NotchService.shared.syncWithPreferences()
        if !NotchLyricsSupport.isEnabled() { NotchLyricsService.shared.stop() }
        NotchMusicService.shared.syncQueuePreference()
        if AppFeature.brightness.isAvailable { BrightnessService.shared.syncWithPreferences() }
    }
}

extension NotchControlItem: PanelOrderItem {}
