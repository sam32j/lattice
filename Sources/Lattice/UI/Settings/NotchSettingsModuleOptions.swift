import SwiftUI
import EventKit

extension NotchSettings {
    @ViewBuilder func moduleOptions(_ module: NotchModule) -> some View {
        switch module {
        case .controls, .mixer, .system, .hub:
            EmptyView()
        case .music:
            musicModuleOptions
        case .notifications:
            notificationsModuleOptions
        case .downloads:
            NotchDownloadsSettingsControls()
                .toggleStyle(TrailingSwitchToggleStyle())
        case .calendar:
            calendarModuleOptions
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
        case .snippets:
            destination(FeatureStrings.snippets(l10n.language).pageTitle, symbol: "text.append", value: $snippetsWindow, available: AppFeature.textSnippets.isAvailable)
        }
    }

    var activityPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 3) {
                    Text(editor.resting).font(.headline)
                    Text(NotchSettingsCopy.idleHint(l10n.language))
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 10) {
                    // With the companion on, the island rests with it when it
                    // has nothing else to show, so that choice is the companion,
                    // unless it hides in the island when idle.
                    idleChoice(.none, title: restsWithMascot ? FeatureStrings.notchMascot(l10n.language).title : text.idleNone,
                               symbol: "minus")
                    if PowerSampler.hasInternalBattery {
                        idleChoice(.battery, title: text.battery, symbol: "battery.75percent")
                    }
                    idleChoice(.agents, title: FeatureStrings.notchAgents(l10n.language).restingTitle, symbol: "sparkles",
                               reason: "Require “AI Usage”", fix: {
                        pageAction(.agents, feature: .notchAgents)()
                    })
                }
                .disabled(hover && hideUntilHover)
                let liveActivityStrings = FeatureStrings.notchLiveActivitySettings(l10n.language)
                Divider()
                Text(NotchSettingsCopy.liveActivity(l10n.language)).font(.headline)
                switchRow("menubar.rectangle",
                          liveActivityStrings.onlyShowActivityWhenRoom,
                          caption: liveActivityStrings.onlyShowActivityWhenRoomHint,
                          isOn: Binding(get: { !coversMenus }, set: { coversMenus = !$0 }))
                switchRow("arrow.up.left.and.arrow.down.right",
                          liveActivityStrings.hideActivityInFullscreen,
                          caption: liveActivityStrings.hideActivityInFullscreenHint,
                          isOn: $hideInFullscreen)
                switchRow("lock.display",
                          liveActivityStrings.showActivityOnLockScreen,
                          isOn: $lockScreen)
                Divider()
                let volumeAvailable = AppFeature.mixer.isAvailable
                let brightnessAvailable = AppFeature.brightness.isAvailable && brightnessControlEnabled
                let microphoneAvailable = AppFeature.micMute.isAvailable
                let hasBattery = PowerSampler.hasInternalBattery
                let batteryAvailable = true
                let accessoriesAvailable = true
                let musicAvailable = NotchSupport.modules().contains(.music)
                let keepAwakeAvailable = AppFeature.keepAwake.isAvailable

                let accessoryBinding = islandFeatureBinding(.notchAccessories, value: $accessoriesEnabled)

                let indicatorStates: [(available: Bool, on: Bool)] = [
                    (volumeAvailable, volume),
                    (brightnessAvailable, brightness),
                    (true, keyboardLight),
                    (microphoneAvailable, microphone),
                    hasBattery ? (batteryAvailable, battery) : nil,
                    (accessoriesAvailable, accessoryBinding.wrappedValue),
                    (keepAwakeAvailable, keepAwakeActivity),
                    (true, clipboard),
                    (musicAvailable, trackChange),
                    (true, inputSource)
                ].compactMap { $0 }

                let onCount = indicatorStates.filter { $0.available && $0.on }.count
                let needSetupCount = indicatorStates.filter { !$0.available }.count
                let indicatorsSummary = needSetupCount > 0 ? "\(onCount) on · \(needSetupCount) need setup" : "\(onCount) on"

                HStack(alignment: .firstTextBaseline) {
                    Text(editor.feedback).font(.headline)
                    Spacer()
                    Text(indicatorsSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    IndicatorListRow(symbol: "speaker.wave.2", title: text.volume,
                                     subtitle: "Require “Audio Output Control”",
                                     available: volumeAvailable, isOn: $volume,
                                     unavailableAction: { AppFeature.mixer.showInFeatures() })
                    Divider()
                    IndicatorListRow(symbol: "sun.max", title: text.brightness,
                                     subtitle: "Require “Display Control”",
                                     available: brightnessAvailable, isOn: $brightness,
                                     unavailableAction: {
                                         router.request(FeatureSettingsDestination(.energy, sectionAnchor: .brightness))
                                     })
                    Divider()
                    IndicatorListRow(symbol: "light.max", title: FeatureStrings.brightness(l10n.language).keyboardLight,
                                     available: true, isOn: $keyboardLight)
                    Divider()
                    IndicatorListRow(symbol: "mic", title: l10n.language == .enUS ? "Mute Status" : l10n.s.mixerInputTitle,
                                     subtitle: "Require “Audio Input Control”",
                                     available: microphoneAvailable, isOn: $microphone,
                                     unavailableAction: { AppFeature.micMute.showInFeatures() })
                    if hasBattery {
                        Divider()
                        IndicatorListRow(symbol: "battery.75percent", title: text.battery,
                                         available: true, isOn: $battery)
                    }
                    Divider()
                    IndicatorListRow(symbol: "headphones", title: FeatureStrings.notchActivities(l10n.language).accessories,
                                     available: true, isOn: accessoryBinding)
                    Divider()
                    IndicatorListRow(symbol: NotchControlItem.keepAwake.symbol, title: l10n.s.keepAwakeTitle,
                                     subtitle: "Require “Stay Awake”",
                                     available: keepAwakeAvailable, isOn: $keepAwakeActivity,
                                     unavailableAction: {
                                         router.request(FeatureSettingsDestination(.energy, sectionAnchor: .keepAwake))
                                     })
                    Divider()
                    IndicatorListRow(symbol: "doc.on.clipboard",
                                     title: SettingsFollowupLabels.text(.clipboardActivity, l10n.language),
                                     available: true, isOn: $clipboard)
                    Divider()
                    IndicatorListRow(symbol: "music.note", title: text.newTrack,
                                     subtitle: "Require “Music”",
                                     available: musicAvailable, isOn: $trackChange,
                                     unavailableAction: pageAction(.music, feature: nil))
                    Divider()
                    IndicatorListRow(symbol: "keyboard", title: text.inputSource,
                                     available: true, isOn: $inputSource)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if enabled, (volume || brightness || keyboardLight), !permissions.accessibility { PermissionRow(kind: .accessibility) }
            }
            destinationsCard
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

private struct IndicatorListRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    let available: Bool
    @Binding var isOn: Bool
    var unavailableAction: (() -> Void)? = nil

    private var amberColor: Color {
        Color.orange
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(available && isOn ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if !available, let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(amberColor)
                }
            }

            Spacer()

            if available {
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            } else if let unavailableAction {
                Button(action: unavailableAction) {
                    Text("Enable")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
