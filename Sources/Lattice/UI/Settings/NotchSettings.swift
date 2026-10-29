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
    @AppStorage(DefaultsKey.notchOutlineEnabled) var outlineEnabled = false
    @AppStorage(DefaultsKey.notchHideMenuBarGap) var hideMenuBarGap = true
    @AppStorage(DefaultsKey.notchCustomWidth) var customWidth = NotchSize.defaultWidth
    @AppStorage(DefaultsKey.notchCustomHeight) var customHeight = NotchSize.defaultHeight
    @AppStorage(DefaultsKey.notchCameraFitWidth) var cameraFitWidth = 0.0
    @AppStorage(DefaultsKey.notchCameraFitHeight) var cameraFitHeight = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitWidth) var capsuleFitWidth = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitHeight) var capsuleFitHeight = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitDrop) var capsuleFitDrop = 0.0
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

    var configuration: [String] {
        [String(enabled), String(calendarEnabled), String(calendarCountdown), String(calendarTimeLeft),
         String(notificationsEnabled), String(dismissNativeNotifications), String(gesturesEnabled),
         String(lyricsEnabled), String(lyricsOnline), String(browserCovers), String(queueEnabled), String(liveEqualizer),
         String(showPlayingMusic), String(includeOtherPlayers), idle, hiddenControls, controlOrder, size,
         String(timerEnabled), String(timerSoundEnabled), String(hideTimerCountdown),
         String(cameraEnabled), String(accessoriesEnabled), String(outlineEnabled), String(hideMenuBarGap),
         String(customWidth), String(customHeight), String(cameraFitWidth), String(cameraFitHeight),
         String(capsuleFitWidth), String(capsuleFitHeight), String(capsuleFitDrop), String(hapticFeedback),
         String(shelfWindow), String(dragReveal), String(appPanel),
         String(hoverExpand), String(hideUntilHover), String(hiddenShowsActivity), String(hideInFullscreen), String(coversMenus),
         display, silhouette, String(hover), hidden, order, String(volume), String(inputSource),
         String(brightness), String(keyboardLight),
         String(microphone), String(battery), String(clipboard), String(clipboardWindow), String(snippetsWindow), clipboardCardSize,
         String(capture), String(trackChange), captureAction, String(showInCaptures),
         String(returnHome), homeModule, String(opensActivity), String(scratchpad),
         String(agentsEnabled), String(watchEnabled), String(keepAwakeActivity), String(shortcutEnabled)]
    }

    var access: Binding<NotchQuickAccessConfiguration> {
        Binding(get: { NotchQuickAccessConfiguration.stored() }, set: { accessData = $0.encoded })
    }

    var orderedModules: [NotchModule] {
        let stored = order.split(separator: ",").compactMap { NotchModule(rawValue: String($0)) }
        var seen = Set<NotchModule>()
        return (stored + NotchSupport.rootModules).filter { seen.insert($0).inserted && NotchSupport.isExploreModule($0) }
    }

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
        .padding(.horizontal, 22).padding(.top, 22)
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
        tab = .content
        contentSelection = .companion
    }

    @ViewBuilder
    var combinedPageView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsCard {
                        SettingsRow(symbol: AppFeature.notch.symbolName, title: text.enable,
                                    experimentalBadge: FeatureStrings.hub(l10n.language).experimentalBadge,
                                    caption: text.description) {
                            PermissionGatedToggle(text.enable, isOn: islandFeatureBinding(.notch, value: $enabled))
                                .labelsHidden().toggleStyle(.switch)
                        }
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
                        VStack(alignment: .leading, spacing: 12) {
                            Text(editor.layout).font(.title3.weight(.semibold))
                            layoutPage
                        }
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
                .padding(.bottom, 22)
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

    @ViewBuilder
    func contentDetailView(selection: NotchContentDestination) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                contentSelection = nil
            } label: {
                Label(FeatureStrings.notch(l10n.language).title, systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            if selection == .companion {
                NotchMascotSettings(embedded: true)
                    .frame(minHeight: 0, maxHeight: .infinity)
            } else {
                moduleDetail
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    /// A section of the island can ask for its own options; the hint is one-shot.
    func consumeModuleHint() {
        guard let module = router.notchModule else { return }
        router.notchModule = nil
        selectedModule = module
        contentSelection = .module(module)
        tab = .content
    }

    func sync() {
        NotchService.shared.syncWithPreferences()
        if !NotchLyricsSupport.isEnabled() { NotchLyricsService.shared.stop() }
        NotchMusicService.shared.syncQueuePreference()
        if AppFeature.brightness.isAvailable { BrightnessService.shared.syncWithPreferences() }
    }

}


extension NotchControlItem: PanelOrderItem {}

/// A standard menu bar on a display without a camera, at half size, with
/// the resting island in it.
struct NotchSilhouetteSample: View {
    let silhouette: NotchSilhouette

    var body: some View {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 0,
                                     cameraWidth: 0, menuBarHeight: 24, silhouette: silhouette)
        let island = geometry.restingSize(showsContent: false)
        ZStack(alignment: .top) {
            Rectangle().fill(.primary.opacity(0.08)).frame(height: geometry.menuBarHeight)
            // Menus on the left and status items on the right, clear of the island.
            HStack(spacing: 9) {
                ForEach([26, 36, 30], id: \.self) { width in
                    Capsule().fill(.primary.opacity(0.22)).frame(width: CGFloat(width), height: 8)
                }
                Spacer(minLength: 0)
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(.primary.opacity(0.22)).frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: geometry.menuBarHeight)
            NotchShape.island(height: island.height, geometry: geometry).fill(.black)
                .frame(width: island.width, height: island.height)
        }
        .frame(width: 400, height: 48, alignment: .top)
        .background(.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(0.5)
        .frame(width: 200, height: 24)
        .accessibilityHidden(true)
    }
}
