import SwiftUI
import EventKit

extension NotchSettings {
    @ViewBuilder func moduleOptions(_ module: NotchModule) -> some View {
        switch module {
        case .controls:
            let primary = [NotchControlItem.music, .volume, .brightness, .keyboardLight]
            HStack(spacing: 10) {
                ForEach(primary) { item in
                    toggleCard(item.title(l10n), symbol: item.symbol, value: controlBinding(item), available: item.isAvailable(),
                               reason: controlReason(item), reservesReason: !primary.allSatisfy { $0.isAvailable() },
                               unavailableAction: controlUnavailableAction(item))
                }
            }
            Text(text.controlShortcuts).font(.subheadline.weight(.medium))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                ForEach(orderedShortcuts) { item in
                    PanelReorderableItem(item: item,
                        order: Binding(get: { orderedShortcuts }, set: { controlOrder = $0.map(\.rawValue).joined(separator: ",") }),
                        dragging: $draggingControl) {
                        toggleCard(item.title(l10n), symbol: item.symbol, value: controlBinding(item), available: item.isAvailable(),
                                   reason: controlReason(item), reservesReason: !orderedShortcuts.allSatisfy { $0.isAvailable() },
                                   unavailableAction: controlUnavailableAction(item))
                    }
                }
            }
            Divider()
            let activities = FeatureStrings.notchActivities(l10n.language)
            SettingsFeatureSwitchRow(symbol: NotchControlItem.keepAwake.symbol, title: activities.keepAwakeActivity,
                                     caption: activities.keepAwakeActivityHint, isOn: $keepAwakeActivity, feature: .keepAwake)
        case .music:
            let music = FeatureStrings.notchMusicExtras(l10n.language)
            switchRow("music.note", text.playingMusic, isOn: $showPlayingMusic)
            switchRow("play.rectangle", music.includeOtherPlayers, isOn: $includeOtherPlayers)
            SettingsRow(symbol: "arrow.up.forward.app", title: music.preferredPlayer, caption: music.preferredPlayerHint) {
                Picker(music.preferredPlayer, selection: $preferredPlayer) {
                    Text(music.automaticSource).tag(NotchPreferredPlayer.automatic)
                    ForEach(NotchPreferredPlayer.choices(in: preferredPlayers ?? [], including: preferredPlayer), id: \.bundleID) { app in
                        Text(app.name).tag(app.bundleID)
                    }
                }
                .labelsHidden()
            }
            .task {
                guard let choices = await NotchPreferredPlayer.loadInstalled(), !Task.isCancelled else { return }
                preferredPlayers = choices
            }
            switchRow("text.quote", music.enableLyrics, isOn: islandFeatureBinding(.notchLyrics, value: $lyricsEnabled))
            if lyricsEnabled, AppFeature.notchLyrics.isAvailable {
                switchRow("globe", music.online, caption: music.onlineHint, isOn: $lyricsOnline)
                    .padding(.leading, settingsRowTextInset)
            }
            switchRow("photo", music.browserCovers, caption: music.browserCoversHint, isOn: $browserCovers)
            switchRow("list.bullet", music.enableQueue, caption: music.queueDescription,
                      isOn: islandFeatureBinding(.notchQueue, value: $queueEnabled))
            switchRow("waveform", music.liveEqualizer,
                                     caption: NotchAudioLevelSupport.isSupported ? music.liveEqualizerHint : music.liveEqualizerUnavailable,
                                     isOn: islandFeatureBinding(.notchLiveEqualizer, value: $liveEqualizer))
                .disabled(!NotchAudioLevelSupport.isSupported)
        case .notifications:
            let notifications = FeatureStrings.notchNotifications(l10n.language)
            SettingsRow(symbol: "bell.slash", title: notifications.hideSystemBanner, caption: notifications.hideSystemBannerHint) {
                PermissionGatedToggle(notifications.hideSystemBanner, isOn: $dismissNativeNotifications).labelsHidden()
            }
            if notificationsEnabled, !permissions.accessibility { PermissionRow(kind: .accessibility) }
        case .downloads:
            NotchDownloadsSettingsControls()
                .toggleStyle(TrailingSwitchToggleStyle())
        case .calendar:
            let calendar = FeatureStrings.notchCalendar(l10n.language)
            Text(calendar.permission).font(.callout).foregroundStyle(.secondary)
            if permissions.calendarAccess == .fullAccess {
                Label(l10n.s.permissionGranted, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button(calendar.allow, action: permissions.requestCalendar).disabled(permissions.requestingCalendar)
                Button(calendar.settings, action: permissions.openCalendarSettings)
            }
            Divider()
            switchRow("calendar.badge.clock", calendar.countdown, caption: calendar.countdownHint,
                      isOn: $calendarCountdown)
            switchRow("hourglass", calendar.timeLeft, caption: calendar.timeLeftHint, isOn: $calendarTimeLeft)
            switchRow("number", calendar.weekNumbers, isOn: $calendarWeekNumbers)
            if permissions.calendarAccess == .fullAccess { NotchCalendarSelection() }
        case .timer:
            let activities = FeatureStrings.notchActivities(l10n.language)
            switchRow("eye.slash", activities.hideTimerCountdown,
                      isOn: $hideTimerCountdown)
                .disabled(!AppFeature.notchTimer.isAvailable)
            switchRow("speaker.wave.2", activities.soundEnabled, isOn: $timerSoundEnabled)
                .disabled(!AppFeature.notchTimer.isAvailable)
        case .camera:
            Text(FeatureStrings.notchActivities(l10n.language).cameraHint).font(.callout).foregroundStyle(.secondary)
            if permissions.camera == .granted {
                Label(l10n.s.permissionGranted, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button(l10n.s.permissionRequest, action: permissions.requestCamera)
                Button(l10n.s.permissionOpenSettings, action: permissions.openCameraSettings)
            }
        case .files:
            destination(text.files, symbol: "tray.full", value: $shelfWindow, available: AppFeature.shelf.isAvailable)
            if shelfWindow { switchRow("hand.draw", text.dragReveal, isOn: $dragReveal) }
            if AppFeature.mediaTools.isAvailable {
                Text(FeatureStrings.notchFiles(l10n.language).optimizeDropHint)
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .clipboard:
            destination(FeatureStrings.clipboard(l10n.language).title, symbol: "doc.on.clipboard", value: $clipboardWindow, available: AppFeature.clipboardHistory.isAvailable)
            switchRow("doc.on.clipboard", text.clipboardActivity, caption: text.privacy, isOn: $clipboard)
            if clipboardWindow, AppFeature.clipboardHistory.isAvailable {
                let size = FeatureStrings.notchClipboardSize(l10n.language)
                VStack(alignment: .leading, spacing: 6) {
                    SettingsChoiceRow(symbol: "rectangle.compress.vertical", title: size.entrySize,
                                      selection: Binding(get: { NotchClipboardCardSize(stored: clipboardCardSize) },
                                                         set: { clipboardCardSize = $0.rawValue })) {
                        Text(size.compact).tag(NotchClipboardCardSize.compact)
                        Text(size.comfortable).tag(NotchClipboardCardSize.comfortable)
                    }
                    Text(size.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, settingsRowTextInset)
                }
            }
        case .captures:
            if AppFeature.screenshot.isAvailable {
                ScreenshotDefaultActionPicker(strings: FeatureStrings.screenshot(l10n.language), selection: $captureAction)
                    .padding(.leading, settingsRowTextInset)
            }
        case .scratchpad:
            destination(FeatureStrings.scratchpad(l10n.language).pageTitle, symbol: "note.text", value: $scratchpad)
        case .agents:
            NotchAgentsSettingsControls()
        case .watch:
            NotchWatchSettingsControls()
                .toggleStyle(TrailingSwitchToggleStyle())
        case .videoDownloader:
            VideoDownloaderDestinationRow()
        case .mixer, .system, .hub:
            EmptyView()
        }
    }

    var activityPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: editor.resting) {
                HStack(alignment: .top, spacing: 10) {
                    // With the companion on, the island rests with it when it
                    // has nothing else to show, so that choice is the companion,
                    // unless it hides in the island when idle.
                    idleChoice(.none, title: restsWithMascot ? FeatureStrings.notchMascot(l10n.language).title : text.idleNone,
                               symbol: "minus")
                    if PowerSampler.hasInternalBattery {
                        idleChoice(.battery, title: text.battery, symbol: "battery.75percent",
                                   reason: AppFeature.monitorPower.enableReason(l10n)) { AppFeature.monitorPower.showInFeatures() }
                    }
                    idleChoice(.music, title: text.music, symbol: "music.note",
                               reason: pageReason(.music, feature: nil), fix: pageAction(.music, feature: nil))
                    // Offered once the section is on, and kept while it is the
                    // saved choice, waiting like the others.
                    if NotchSupport.canRest(with: .agents) || idle == NotchIdleContent.agents.rawValue {
                        idleChoice(.agents, title: FeatureStrings.notchAgents(l10n.language).restingTitle, symbol: "sparkles",
                                   reason: pageReason(.agents, feature: .notchAgents), fix: pageAction(.agents, feature: .notchAgents))
                    }
                }
                if restingChoice == .battery { lowBatteryControls }
                switchRow("menubar.rectangle", text.coverMenus, caption: text.coverMenusHint, isOn: $coversMenus)
            }
            SettingsCard(title: editor.feedback) {
                let volumeAvailable = AppFeature.mixer.isAvailable
                let brightnessAvailable = AppFeature.brightness.isAvailable && brightnessControlEnabled
                let keyboardLightAvailable = AppFeature.brightness.isAvailable && BrightnessService.keyboardLightIsSupported
                let microphoneAvailable = AppFeature.micMute.isAvailable
                // A Mac without a battery has no battery notices, so that card
                // is left out rather than shown waiting for Power.
                let hasBattery = PowerSampler.hasInternalBattery
                let batteryAvailable = AppFeature.monitorPower.isAvailable
                let accessoriesAvailable = AppFeature.monitorPower.isAvailable
                let clipboardAvailable = AppFeature.clipboardHistory.isAvailable && clipboardHistoryEnabled
                    && NotchSupport.modules().contains(.clipboard)
                let musicAvailable = NotchSupport.modules().contains(.music)
                let reserves = ![volumeAvailable, brightnessAvailable, keyboardLightAvailable, microphoneAvailable,
                                 batteryAvailable || !hasBattery, accessoriesAvailable, clipboardAvailable,
                                 musicAvailable].allSatisfy { $0 }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 10)], spacing: 10) {
                    toggleCard(text.volume, symbol: "speaker.wave.2", value: $volume, available: volumeAvailable,
                               reason: AppFeature.mixer.enableReason(l10n), reservesReason: reserves,
                               unavailableAction: { AppFeature.mixer.showInFeatures() })
                    toggleCard(text.brightness, symbol: "sun.max", value: $brightness, available: brightnessAvailable,
                               reason: AppFeature.brightness.isAvailable ? editor.enableSetting(FeatureStrings.brightness(l10n.language).enable) : AppFeature.brightness.enableReason(l10n),
                               reservesReason: reserves,
                               unavailableAction: {
                                   if AppFeature.brightness.isAvailable {
                                       router.request(AppFeature.brightness.settingsDestination)
                                   } else {
                                       AppFeature.brightness.showInFeatures()
                                   }
                               })
                    toggleCard(FeatureStrings.brightness(l10n.language).keyboardLight, symbol: "light.max", value: $keyboardLight,
                              available: keyboardLightAvailable,
                              reason: !AppFeature.brightness.isAvailable ? AppFeature.brightness.enableReason(l10n) : editor.keyboardLightUnavailable,
                              reservesReason: reserves,
                              unavailableAction: !AppFeature.brightness.isAvailable ? { AppFeature.brightness.showInFeatures() } : nil)
                    toggleCard(l10n.s.mixerInputTitle, symbol: "mic", value: $microphone, available: microphoneAvailable,
                               reason: AppFeature.micMute.enableReason(l10n), reservesReason: reserves,
                               unavailableAction: { AppFeature.micMute.showInFeatures() })
                    if hasBattery {
                        toggleCard(text.battery, symbol: "battery.75percent", value: $battery, available: batteryAvailable,
                                   reason: AppFeature.monitorPower.enableReason(l10n), reservesReason: reserves,
                                   unavailableAction: { AppFeature.monitorPower.showInFeatures() })
                    }
                    NotchAccessorySettingsItem(title: FeatureStrings.notchActivities(l10n.language).accessories,
                              enabled: islandFeatureBinding(.notchAccessories, value: $accessoriesEnabled),
                              available: accessoriesAvailable,
                              reason: AppFeature.monitorPower.enableReason(l10n),
                              reservesReason: reserves,
                              unavailableAction: {
                                  AppFeature.monitorPower.showInFeatures()
                              })
                    toggleCard(SettingsFollowupLabels.text(.clipboardActivity, l10n.language), symbol: "doc.on.clipboard", value: $clipboard,
                               available: clipboardAvailable, reason: clipboardFeedbackReason, reservesReason: reserves,
                               unavailableAction: { openClipboardFeedbackSetup() })
                    toggleCard(text.newTrack, symbol: "music.note", value: $trackChange, available: musicAvailable,
                               reason: pageReason(.music, feature: nil), reservesReason: reserves,
                               unavailableAction: pageAction(.music, feature: nil))
                    // A layout change is read straight from the system, so
                    // this card never waits on another feature.
                    toggleCard(text.inputSource, symbol: "keyboard", value: $inputSource,
                               available: true, reservesReason: reserves)
                }
                if accessoriesEnabled { Text(FeatureStrings.notchActivities(l10n.language).accessoryDescription).font(.caption).foregroundStyle(.secondary) }
                if enabled, (volume || brightness || keyboardLight), !permissions.accessibility { PermissionRow(kind: .accessibility) }
            }
            let locked = FeatureStrings.notchLockScreen(l10n.language)
            SettingsCard(title: locked.title) {
                switchRow("lock.display", locked.show, caption: locked.showHint, isOn: $lockScreen)
            }
        }
    }


}

private struct VideoDownloaderDestinationRow: View {
    @ObservedObject private var downloader = VideoDownloader.shared

    var body: some View {
        HStack {
            Label(VideoDownloaderStrings.saveTo, systemImage: "folder")
            Spacer()
            Button(downloader.destination?.lastPathComponent ?? VideoDownloaderStrings.defaultFolder) {
                downloader.chooseDestination()
            }
        }
    }
}
