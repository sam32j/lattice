// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Per-app volume sliders, the mixer macOS never shipped. Shows every app
/// holding an audio connection (a green dot marks the ones playing right now).
/// 100% is untouched passthrough; below it attenuates and above it (up to 200%)
/// boosts, with the slider and percentage turning amber in the boost range.
struct MixerSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchPresentation) private var inNotch
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var preciseVolumeRoller = PreciseVolumeRollerService.shared
    @AppStorage(DefaultsKey.mixerAppArrangement)
    private var arrangementValue = ""
    @AppStorage(DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect)
    private var lowerOnHeadphonesDisconnect = false
    @AppStorage(DefaultsKey.mixerHeadphonesDisconnectVolumePercent)
    private var headphonesDisconnectVolumePercent = Defaults.defaultMixerHeadphonesDisconnectVolumePercent
    @AppStorage(DefaultsKey.preciseVolumeRollerEnabled)
    private var preciseVolumeRollerEnabled = false
    @AppStorage("audioOutputLastUnmutedVolume")
    private var lastUnmutedOutputVolume: Double = 0.5
    @State private var draggingOutputVolume: Double? = nil
    @State private var showInactiveApps = false
    @State private var lastVolumeChangeTimes: [String: CFAbsoluteTime] = [:]
    @State private var activeSliderTrackingAppIDs: Set<String> = []
    @State private var stabilizedActiveAppIDs: Set<String> = []
    @State private var stabilizedInactiveAppIDs: Set<String> = []
    @AppStorage(DefaultsKey.volumeMixerEnabled) private var volumeMixerEnabled = true
    var settingsMode = true

    var body: some View {
        audioOutputSettingsCard
            .onAppear {
                updateStabilizedListsIfNeeded()
                mixer.refreshApps()
            }
            .onChange(of: mixer.apps) { _, _ in
                updateStabilizedListsIfNeeded()
            }
    }

    private var audioOutputSettingsCard: some View {
        SettingsCard(
            symbol: "speaker.wave.2",
            title: l10n.s.volumeMixerEnable,
            headerSpacing: 0,
            headerAccessory: {
                Toggle(l10n.s.volumeMixerEnable, isOn: $volumeMixerEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                    .accessibilityLabel(l10n.s.volumeMixerEnable)
                    .onChange(of: volumeMixerEnabled) { _, enabled in
                        settingsApplyFeatureSwitch(enabled: enabled) {
                            let enabled = UserDefaults.standard.bool(forKey: DefaultsKey.volumeMixerEnabled)
                            FeatureRuntime.shared.setAvailable([.mixer], enabled)
                            AppVolumeMixer.shared.syncWithPreferences()
                            PreciseVolumeRollerService.shared.syncWithPreferences()
                        }
                    }
            }
        ) {
            audioOutputSettingsContent
                .padding(.top, SettingsCard<EmptyView>.defaultHeaderSpacing)
                .settingsCollapsible(isExpanded: volumeMixerEnabled)
        }
        .settingsExpansionAnimation(value: [volumeMixerEnabled, lowerOnHeadphonesDisconnect, preciseVolumeRollerEnabled])
    }

    private var audioOutputSettingsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                outputDeviceRow
                outputVolumeRow
                systemSoundsRow
                headphoneDisconnectSection
                volumeKeyStepRow
            }
            .padding(.leading, settingsRowTextInset)

            Divider()

            appVolumesSection
        }
    }

    private var headphoneDisconnectSection: some View {
        VStack(alignment: .leading, spacing: lowerOnHeadphonesDisconnect ? 14 : 0) {
            headphoneDisconnectRow
            targetVolumeRow
                .settingsCollapsible(isExpanded: lowerOnHeadphonesDisconnect)
        }
    }

    private var outputDeviceRow: some View {
        HStack(spacing: 8) {
            Text("Audio output device")
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 8)

            Picker("Audio output device", selection: universalOutputSelectionBinding) {
                if mixer.currentOutputDeviceUID == nil {
                    Text(l10n.s.mixerOutputUnavailable)
                        .tag(MixerRoutingSupport.systemDefaultSelectionID)
                }
                ForEach(universalOutputDevices) { device in
                    Text(outputDeviceTitle(device))
                        .tag(device.uid)
                }
                if let selected = mixer.currentOutputDeviceUID,
                   !universalOutputDevices.contains(where: { $0.uid == selected }) {
                    Text(l10n.s.mixerOutputUnavailable)
                        .tag(selected)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.regular)
            .frame(width: 164)
            .disabled(universalOutputDevices.isEmpty)
        }
    }

    private var outputVolumeRow: some View {
        HStack(spacing: 8) {
            Text(l10n.s.mixerOutputLevelLabel)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                toggleOutputMute()
            } label: {
                Image(systemName: isSystemOutputMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSystemOutputMuted ? Color.red : Color.secondary)
                    .frame(width: 18, alignment: .center)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSystemOutputMuted ? l10n.s.actionUnmute : l10n.s.actionMute)

            DeviceControlsSlider(
                title: l10n.s.mixerOutputLevelLabel,
                value: systemOutputVolumeBinding,
                range: 0...1,
                step: 0.01,
                readout: "\(Int((displayedSystemOutputVolume * 100).rounded()))%",
                onEditingChanged: { editing in
                    if !editing {
                        draggingOutputVolume = nil
                    }
                }
            )
            .frame(width: 140)
        }
    }

    private var systemSoundsRow: some View {
        HStack(spacing: 8) {
            Text("Play system sound at")
                .font(.body)
                .lineLimit(1)
                .frame(minWidth: 105, alignment: .leading)

            Spacer(minLength: 6)

            Picker("Play system sound at", selection: systemSoundOutputSelectionBinding) {
                if mixer.currentSystemSoundOutputDeviceUID == nil {
                    Text(l10n.s.mixerOutputUnavailable)
                        .tag(MixerRoutingSupport.systemDefaultSelectionID)
                }
                ForEach(systemSoundOutputDevices) { device in
                    Text(systemSoundOutputDeviceTitle(device))
                        .tag(device.uid)
                }
                if let selected = mixer.currentSystemSoundOutputDeviceUID,
                   !systemSoundOutputDevices.contains(where: { $0.uid == selected }) {
                    Text(l10n.s.mixerOutputUnavailable)
                        .tag(selected)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.regular)
            .frame(width: 164)
            .disabled(systemSoundOutputDevices.isEmpty)
        }
    }

    private var headphoneDisconnectRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lower volume on headphone disconnect")
                    .font(.body)
                Text("Applies to wired and Bluetooth headphones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("Lower volume on headphone disconnect",
                   isOn: $lowerOnHeadphonesDisconnect.animation(reduceMotion ? nil : .settingsExpansion))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
        }
    }

    private var targetVolumeRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Lower volume to")
                .font(.body)

            Spacer(minLength: 12)

            DeviceControlsSlider(
                title: "Lower volume to",
                value: headphonesDisconnectVolumeDoubleBinding,
                range: Double(Defaults.minimumMixerHeadphonesDisconnectVolumePercent)...100,
                step: 1,
                readout: "\(headphonesDisconnectDisplayPercent)%"
            )
            .frame(width: 140)
        }
    }

    private var volumeKeyStepRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume key step")
                        .font(.body)
                    Text("Changes how much each key press adjusts volume.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Picker("Volume key step", selection: Binding(
                    get: { preciseVolumeRollerEnabled },
                    set: { newValue in
                        preciseVolumeRollerEnabled = newValue
                        if newValue { permissions.requestAccessibility() }
                        PreciseVolumeRollerService.shared.syncWithPreferences()
                    }
                )) {
                    Text("Standard").tag(false)
                    Text("Smaller").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .help("Changes how much each key press adjusts volume.")
            }

            if preciseVolumeRollerEnabled, !permissions.accessibility {
                Button {
                    Permissions.shared.openAccessibilitySettings()
                } label: {
                    Label(l10n.s.permissionOpenSettings, systemImage: "hand.raised")
                }
                .buttonStyle(.link)
                .font(.system(size: 10.5, weight: .medium))
            } else if preciseVolumeRoller.tapFailed {
                inputMessage(l10n.s.preciseVolumeRollerTapFailed,
                             systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private var appVolumesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LatticeSymbol("wave.3.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text("App Volumes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 2)

            if !AppVolumeMixer.isSupported {
                emptyLabel(l10n.s.mixerUnavailable)
            } else if mixer.needsPermission {
                permissionHint
            } else if orderedApps.isEmpty {
                emptyLabel(l10n.s.mixerEmpty)
            } else {
                if activeApps.isEmpty {
                    Text("No app playing")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(activeApps.enumerated()), id: \.element.id) { index, app in
                        if index > 0 {
                            Divider().padding(.horizontal, 4)
                        }
                        MixerSettingsAppRow(
                            app: app,
                            isPinned: arrangement.isPinned(app.persistenceID),
                            active: app.isPlaying,
                            onTogglePin: {
                                updateArrangement { $0.togglePin(app.persistenceID ?? "") }
                                updateStabilizedListsIfNeeded(force: true)
                            },
                            onVolumeChanged: {
                                let now = CFAbsoluteTimeGetCurrent()
                                lastVolumeChangeTimes[app.id] = now
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
                                    updateStabilizedListsIfNeeded()
                                }
                            },
                            onSliderTrackingChanged: { isTracking in
                                if isTracking {
                                    activeSliderTrackingAppIDs.insert(app.id)
                                } else {
                                    activeSliderTrackingAppIDs.remove(app.id)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
                                        updateStabilizedListsIfNeeded()
                                    }
                                }
                            }
                        )
                    }
                }

                if !inactiveApps.isEmpty {
                    Button {
                        withAnimation(reduceMotion ? nil : .settingsExpansion) {
                            showInactiveApps.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 12)
                                .rotationEffect(.degrees(showInactiveApps ? 90 : 0))
                            Text(showInactiveApps
                                 ? "Hide inactive apps"
                                 : "Show inactive apps (\(inactiveApps.count))")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    if showInactiveApps {
                        ForEach(Array(inactiveApps.enumerated()), id: \.element.id) { index, app in
                            if index > 0 {
                                Divider().padding(.horizontal, 4)
                            }
                            MixerSettingsAppRow(
                                app: app,
                                isPinned: arrangement.isPinned(app.persistenceID),
                                active: false,
                                onTogglePin: {
                                    updateArrangement { $0.togglePin(app.persistenceID ?? "") }
                                    updateStabilizedListsIfNeeded(force: true)
                                },
                                onVolumeChanged: {
                                    let now = CFAbsoluteTimeGetCurrent()
                                    lastVolumeChangeTimes[app.id] = now
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
                                        updateStabilizedListsIfNeeded()
                                    }
                                },
                                onSliderTrackingChanged: { isTracking in
                                    if isTracking {
                                        activeSliderTrackingAppIDs.insert(app.id)
                                    } else {
                                        activeSliderTrackingAppIDs.remove(app.id)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
                                            updateStabilizedListsIfNeeded()
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var isInteractingWithAnyApp: Bool {
        if !activeSliderTrackingAppIDs.isEmpty { return true }
        let now = CFAbsoluteTimeGetCurrent()
        return lastVolumeChangeTimes.values.contains { now - $0 < 2.0 }
    }

    private func naturalIsActive(_ app: MixerApp) -> Bool {
        app.isPlaying || arrangement.isPinned(app.persistenceID)
    }

    private func updateStabilizedListsIfNeeded(force: Bool = false) {
        guard force || !isInteractingWithAnyApp else { return }
        let naturalActive = Set(orderedApps.filter { naturalIsActive($0) }.map(\.id))
        let naturalInactive = Set(orderedApps.filter { !naturalIsActive($0) }.map(\.id))
        stabilizedActiveAppIDs = naturalActive
        stabilizedInactiveAppIDs = naturalInactive
    }

    private func isAppEffectivelyActive(_ app: MixerApp) -> Bool {
        let naturalActive = naturalIsActive(app)
        let now = CFAbsoluteTimeGetCurrent()
        let recentlyChanged = now - (lastVolumeChangeTimes[app.id] ?? 0) < 2.0
        let isTracking = activeSliderTrackingAppIDs.contains(app.id)

        if recentlyChanged || isTracking {
            if stabilizedInactiveAppIDs.contains(app.id) {
                return false
            }
            if stabilizedActiveAppIDs.contains(app.id) {
                return true
            }
        }
        return naturalActive
    }

    private var orderedApps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID })
    }

    private var activeApps: [MixerApp] {
        orderedApps.filter { isAppEffectivelyActive($0) }
    }

    private var inactiveApps: [MixerApp] {
        orderedApps.filter { !isAppEffectivelyActive($0) }
    }

    private var headphonesDisconnectDisplayPercent: Int {
        Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent)
    }

    private var headphonesDisconnectVolumeDoubleBinding: Binding<Double> {
        Binding(
            get: { Double(headphonesDisconnectDisplayPercent) },
            set: { headphonesDisconnectVolumePercent = Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(Int($0.rounded())) }
        )
    }

    private var universalOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultOutput)
    }

    private var systemSoundOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultSystemOutput)
    }

    private var universalOutputSelectionBinding: Binding<String> {
        Binding(
            get: { mixer.currentOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
                mixer.setUniversalOutputDeviceUID(selection)
            }
        )
    }

    private var isSystemOutputMuted: Bool {
        mixer.systemOutputMuted == true || (mixer.systemOutputVolume ?? 0) <= 0.001
    }

    private var displayedSystemOutputVolume: Double {
        if let draggingOutputVolume { return draggingOutputVolume }
        if mixer.systemOutputMuted == true { return 0 }
        return mixer.systemOutputVolume ?? 0
    }

    private func toggleOutputMute() {
        NotchService.shared.noteOwnLevelAdjustment(.volume)
        if isSystemOutputMuted {
            let restoreVal = lastUnmutedOutputVolume > 0.001 ? lastUnmutedOutputVolume : (mixer.systemOutputVolume ?? 0.5)
            let finalVal = restoreVal > 0.001 ? restoreVal : 0.5
            mixer.requestOutputAdjustment(volume: finalVal, muted: false)
        } else {
            if let cur = mixer.systemOutputVolume, cur > 0.001 {
                lastUnmutedOutputVolume = cur
            }
            mixer.requestOutputAdjustment(muted: true)
        }
    }

    private func setSystemOutputVolume(_ value: Double) {
        if inNotch {
            // The slider shows the level; the island's header need not repeat it.
            NotchService.shared.noteOwnVolumeAdjustment()
        }
        // Both panels share the key queue, so a drag supersedes an older key.
        mixer.requestOutputAdjustment(volume: value)
    }

    private var systemOutputVolumeBinding: Binding<Double> {
        Binding(
            get: { draggingOutputVolume ?? displayedSystemOutputVolume },
            set: { newValue in
                draggingOutputVolume = newValue
                if isSystemOutputMuted && newValue > 0.001 {
                    NotchService.shared.noteOwnLevelAdjustment(.volume)
                    lastUnmutedOutputVolume = newValue
                    mixer.requestOutputAdjustment(volume: newValue, muted: false)
                } else {
                    if newValue > 0.001 { lastUnmutedOutputVolume = newValue }
                    setSystemOutputVolume(newValue)
                }
            }
        )
    }

    private var systemSoundOutputSelectionBinding: Binding<String> {
        Binding(
            get: {
                mixer.currentSystemSoundOutputDeviceUID
                    ?? MixerRoutingSupport.systemDefaultSelectionID
            },
            set: { selection in
                guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
                mixer.setSystemSoundOutputDeviceUID(selection)
            }
        )
    }

    private var arrangement: MixerAppArrangement { MixerAppArrangement(rawValue: arrangementValue) }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.name
    }

    private func systemSoundOutputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.name
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func updateArrangement(_ change: (inout MixerAppArrangement) -> Void) {
        var updated = arrangement
        change(&updated)
        arrangementValue = updated.rawValue
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }

    private var permissionHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.s.mixerPermissionBody)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(l10n.s.permissionOpenSettings) {
                Permissions.shared.openAudioCaptureSettings()
            }
            .controlSize(.small)
        }
    }
}

/// An individual application row in Audio Output settings, displaying an icon with hover pin overlay,
/// app title, unified output destination selector (Local Mac, Bluetooth/headphones, AirPlay, Default),
/// mute button, and 140px volume boost slider in a single compact row.
struct MixerSettingsAppRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    let app: MixerApp
    let isPinned: Bool
    let active: Bool
    let onTogglePin: () -> Void
    var onVolumeChanged: () -> Void = {}
    var onSliderTrackingChanged: (Bool) -> Void = { _ in }

    @State private var isHovered = false
    @State private var isSliderTracking = false

    private var isAirPlay: Bool {
        app.selectedOutputDeviceUID.map(MixerRoutingSupport.isAirPlaySentinel) == true
    }

    private var isCustomRoute: Bool {
        app.selectedOutputDeviceUID != nil
    }

    private var routeButtonIcon: String {
        guard let selectedUID = app.selectedOutputDeviceUID else {
            return "hifispeaker.2"
        }
        if MixerRoutingSupport.isAirPlaySentinel(selectedUID) {
            return "airplay.audio"
        }
        if app.outputDeviceUnavailable {
            return "speaker.badge.exclamationmark"
        }
        if let device = mixer.outputDevices.first(where: { $0.uid == selectedUID }) {
            return deviceIcon(for: device)
        }
        return "hifispeaker.2"
    }

    private func deviceIcon(for device: MixerOutputDevice) -> String {
        if device.isAirPlay {
            return "airplay.audio"
        } else if device.isHeadphones || device.isBluetooth {
            return NotchAccessorySupport.symbol(for: .audio, name: device.name)
        } else if device.isBuiltIn {
            return PowerSampler.hasInternalBattery ? "laptopcomputer" : "desktopcomputer"
        } else {
            return "hifispeaker.fill"
        }
    }

    private var currentDestinationName: String? {
        guard let selectedUID = app.selectedOutputDeviceUID else { return nil }
        if MixerRoutingSupport.isAirPlaySentinel(selectedUID) {
            return AirPlayRouteManager.currentSpeakerName ?? "AirPlay"
        }
        return mixer.outputDevices.first(where: { $0.uid == selectedUID })?.name
    }

    private var routeTooltip: String {
        if let name = currentDestinationName {
            if app.outputDeviceUnavailable {
                return "Audio destination: Disconnected device"
            }
            return "Audio destination: \(name) (Dedicated)"
        }
        return "Audio destination: Default (Follow System)"
    }

    var body: some View {
        HStack(spacing: 8) {
            appIconView

            Text(app.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Color.primary : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if !app.isBypassed {
                outputDestinationMenu
            }

            Spacer(minLength: 8)

            speakerButton

            if app.isBypassed {
                Text(l10n.s.mixerBypassedCaption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 220, alignment: .trailing)
            } else {
                AppVolumeBoostSlider(
                    title: "\(app.name) volume",
                    value: Binding(
                        get: { app.volume },
                        set: {
                            mixer.setVolume($0, for: app)
                            onVolumeChanged()
                        }
                    ),
                    onEditingChanged: { tracking in
                        isSliderTracking = tracking
                        onSliderTrackingChanged(tracking)
                    }
                )
                .frame(width: 220)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .opacity(active ? 1.0 : 0.65)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        if app.persistenceID != nil {
            Button {
                onTogglePin()
            } label: {
                iconContent
            }
            .buttonStyle(.plain)
            .help(isPinned ? FeatureStrings.mixer(l10n.language).unpin : FeatureStrings.mixer(l10n.language).pin)
        } else {
            iconContent
        }
    }

    /// 30 pt: large enough that the pin badge sits on the icon's corner
    /// instead of hanging off a small icon, still matching the row height.
    private static let iconSize: CGFloat = 30

    private var iconContent: some View {
        Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid, pointSize: Self.iconSize))
            .resizable()
            .frame(width: Self.iconSize, height: Self.iconSize)
            .overlay(alignment: .bottomTrailing) {
                if isPinned || (isHovered && app.persistenceID != nil) {
                    pinBadge
                        .offset(x: 3, y: 3)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else if active && app.isPlaying {
                    greenDotBadge
                        .offset(x: 3, y: 3)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPinned)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.15), value: app.isPlaying)
    }

    /// Always a solid disc, so it reads as a badge in both states: green
    /// when playing and pinned, orange when pinned and not playing, neutral grey
    /// with an outline pin while it only offers pinning on hover.
    private var pinBadge: some View {
        Image(systemName: isPinned ? "pin.fill" : "pin")
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 16, height: 16)
            .background(pinBadgeBackground)
            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
    }

    @ViewBuilder
    private var pinBadgeBackground: some View {
        if isPinned {
            ZStack {
                Circle().fill(Color.orange)
                Circle()
                    .fill(PanelMetricColor.green(for: colorScheme))
                    .opacity(active && app.isPlaying ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.25), value: active && app.isPlaying)
        } else {
            Circle().fill(Color(nsColor: .systemGray))
        }
    }

    private var greenDotBadge: some View {
        Circle()
            .fill(PanelMetricColor.green(for: colorScheme))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
            .frame(width: 16, height: 16)
    }

    @ViewBuilder
    private var outputDestinationMenu: some View {
        Menu {
            Button {
                mixer.setOutputDeviceUID(nil, for: app)
            } label: {
                if app.selectedOutputDeviceUID == nil {
                    Label("Default (Follow System)", systemImage: "checkmark")
                } else {
                    Label("Default (Follow System)", systemImage: "hifispeaker.2")
                }
            }

            let nonAirPlayDevices = mixer.outputDevices.filter { !$0.isAirPlay }
            if !nonAirPlayDevices.isEmpty {
                Divider()
                ForEach(nonAirPlayDevices) { device in
                    Button {
                        mixer.setOutputDeviceUID(device.uid, for: app)
                    } label: {
                        if app.selectedOutputDeviceUID == device.uid {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Label(device.name, systemImage: deviceIcon(for: device))
                        }
                    }
                }
            }

            if app.outputDeviceUnavailable, app.selectedOutputDeviceUID != nil {
                Divider()
                Label(l10n.s.mixerOutputUnavailable, systemImage: "checkmark")
            }
        } label: {
            Image(systemName: routeButtonIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isCustomRoute ? Color.accentColor : Color.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(routeTooltip)
    }

    private var speakerButton: some View {
        Button {
            if (app.volume * 100).rounded() == 100 {
                mixer.toggleMute(app)
            } else {
                mixer.setVolume(1.0, for: app)
            }
            onVolumeChanged()
        } label: {
            Image(systemName: hudSpeakerIcon(for: app.volume))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hudSpeakerColor(for: app.volume))
                .frame(width: 18, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(app.isBypassed)
        .accessibilityLabel(hudSpeakerAccessibilityLabel(for: app))
    }

    private func hudSpeakerIcon(for volume: Double) -> String {
        if volume <= 0.001 {
            return "speaker.slash.fill"
        } else if volume <= 0.33 {
            return "speaker.wave.1.fill"
        } else if volume <= 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func hudSpeakerColor(for volume: Double) -> Color {
        if volume <= 0.001 {
            return Color.secondary
        } else if volume > 1.0 {
            return Color.orange
        } else {
            return Color.secondary
        }
    }

    private func hudSpeakerAccessibilityLabel(for app: MixerApp) -> String {
        if (app.volume * 100).rounded() == 100 {
            return "Mute \(app.name)"
        } else {
            return "Reset \(app.name) volume to 100%"
        }
    }
}
