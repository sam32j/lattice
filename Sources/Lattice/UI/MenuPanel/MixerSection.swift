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
    @AppStorage(DefaultsKey.mixerHideInactiveApps)
    private var hideInactiveApps = false
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
    @State private var optionsExpanded = false
    @State private var normalSliderTint = Color(nsColor: .controlAccentColor)
    @State private var accentRevision = 0
    @State private var lastResolvedAccent: NSColor?
    @State private var editingVolumeID: String?
    @State private var draggingAppID: String?
    @State private var dropTarget: MixerAppDropTarget?
    @State private var lastVolumeChangeTimes: [String: CFAbsoluteTime] = [:]
    @State private var activeSliderTrackingAppIDs: Set<String> = []
    @State private var stabilizedActiveAppIDs: Set<String> = []
    @State private var stabilizedInactiveAppIDs: Set<String> = []
    @AppStorage(DefaultsKey.volumeMixerEnabled) private var volumeMixerEnabled = true
    var collapsible = true
    var settingsMode = false

    private var glassEnabled: Bool {
        LiquidGlassSupport.isSupported
    }

    var body: some View {
        Group {
            if settingsMode {
                audioOutputSettingsCard
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle(l10n.s.mixerSection)
                    mixerControls.panelCard(interactive: false)
                }
            }
        }
        .onReceive(NSApplication.shared.publisher(for: \.effectiveAppearance, options: [.new])) { _ in
            refreshSliderTint()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NSSystemColorsDidChangeNotification"))) { _ in
            refreshSliderTint()
        }
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
            .controlSize(.small)
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
            .controlSize(.small)
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
                    Text("No active apps")
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
                            active: true,
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
                        ForEach(inactiveApps) { app in
                            Divider().padding(.horizontal, 4)
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
        app.isPlaying
            || arrangement.isPinned(app.persistenceID)
            || !MixerRoutingSupport.isUnity(app.volume)
            || app.selectedOutputDeviceUID != nil
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

    private func isActiveApp(_ app: MixerApp) -> Bool {
        isAppEffectivelyActive(app)
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

    private var headphonesDisconnectVolumeBinding: Binding<Int> {
        Binding(
            get: { Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent) },
            set: { headphonesDisconnectVolumePercent = Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent($0) }
        )
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

    private var mixerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            audioDevicesSection

            if AppVolumeMixer.isSupported, (!visibleApps.isEmpty || mixer.needsPermission) {
                Divider()
            }

            if !AppVolumeMixer.isSupported {
                emptyLabel(l10n.s.mixerUnavailable)
            } else if mixer.needsPermission {
                permissionHint
            } else if visibleApps.isEmpty {
                emptyLabel(l10n.s.mixerEmpty)
            } else {
                mixerRows
            }

            Divider()
            optionsDisclosure
        }
    }

    private var audioDevicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            universalOutputPicker
            systemSoundOutputPicker
            if !settingsMode { AudioInputDeviceControls() }
            if let outputSwitchError = mixer.outputSwitchError {
                inputMessage(String(format: l10n.s.mixerSystemOutputErrorFormat, outputSwitchError),
                             systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var optionsDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .settingsExpansion) {
                    optionsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                        .rotationEffect(.degrees(optionsExpanded ? 90 : 0))
                    Text(l10n.s.keepAwakeOptions)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if optionsExpanded {
                MixerOptionsControls(includeSharedAudioFeatures: !settingsMode)
                    .padding(.leading, 19)
            }
        }
    }

    private var universalOutputPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label {
                    Text(l10n.s.mixerSystemOutputTitle)
                        .font(.system(size: 11.5, weight: .medium))
                } icon: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .frame(width: 16)
                }
                .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                Picker(l10n.s.mixerSystemOutputTooltip, selection: universalOutputSelectionBinding) {
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
                .controlSize(.small)
                .frame(width: 164)
                .disabled(universalOutputDevices.isEmpty)
                .help(l10n.s.mixerSystemOutputTooltip)
            }

            if let _ = mixer.systemOutputVolume {
                HStack(spacing: 8) {
                    Button {
                        toggleOutputMute()
                    } label: {
                        Image(systemName: isSystemOutputMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(isSystemOutputMuted ? Color.red : Color.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSystemOutputMuted ? l10n.s.actionUnmute : l10n.s.actionMute)

                    Text(l10n.s.mixerOutputLevelLabel)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    SettingsValueSlider(title: l10n.s.mixerOutputLevelLabel,
                                        value: systemOutputVolumeBinding, range: 0...1, step: 0.01,
                                        readout: "\(Int((displayedSystemOutputVolume * 100).rounded()))%", usesSystemAppearance: true)
                        .frame(width: settingsMode ? 220 : 164)
                }
                .padding(.vertical, 4)
            }

            if universalOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
            }
        }
    }

    private var systemSoundOutputPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label {
                    Text(l10n.s.mixerSoundEffectsOutputTitle)
                        .font(.system(size: 11.5, weight: .medium))
                } icon: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .frame(width: 16)
                }
                .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                Picker(l10n.s.mixerSoundEffectsOutputTooltip,
                       selection: systemSoundOutputSelectionBinding) {
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
                .controlSize(.small)
                .frame(width: 164)
                .disabled(systemSoundOutputDevices.isEmpty)
                .help(l10n.s.mixerSoundEffectsOutputTooltip)
            }

            if systemSoundOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "bell.slash")
            }
        }
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

    private var visibleApps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID }).filter { app in
            MixerRoutingSupport.shouldShowApp(isPlaying: app.isPlaying,
                                              volume: app.volume,
                                              selectedOutputDeviceUID: app.selectedOutputDeviceUID,
                                              hideInactiveApps: hideInactiveApps)
        }
    }


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

    @ViewBuilder
    private var mixerRows: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *), glassEnabled {
            GlassEffectContainer(spacing: 8) {
                rowList
            }
        } else {
            rowList
        }
#else
        rowList
#endif
    }

    @ViewBuilder
    private var rowList: some View {
        ForEach(visibleApps) { app in
            MixerRow(app: app,
                     normalTint: normalSliderTint,
                     accentRevision: accentRevision,
                     glassEnabled: glassEnabled,
                     editingVolumeID: $editingVolumeID,
                     isPinned: arrangement.isPinned(app.persistenceID),
                     togglePin: { updateArrangement { $0.togglePin(app.persistenceID ?? "") } },
                     moveUp: moveAction(for: app, offset: -1),
                     moveDown: moveAction(for: app, offset: 1))
                .modifier(MixerAppReorderModifier(
                    id: app.persistenceID,
                    icon: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32),
                    draggingID: $draggingAppID,
                    target: $dropTarget,
                    dragChanged: { active in
                        if inNotch { NotchService.shared.fileDragChanged(active, internalDrag: true) }
                    },
                    canMove: { source, target in
                        let ids = visibleApps.compactMap(\.persistenceID)
                        return ids.contains(source) && ids.contains(target)
                            && arrangement.isPinned(source) == arrangement.isPinned(target)
                    },
                    move: { source, target, after in
                        updateArrangement {
                            $0.move(source, to: target, after: after,
                                    visibleIDs: visibleApps.compactMap(\.persistenceID))
                        }
                    }))
        }
    }

    private func updateArrangement(_ change: (inout MixerAppArrangement) -> Void) {
        var updated = arrangement
        change(&updated)
        arrangementValue = updated.rawValue
    }

    private func moveAction(for app: MixerApp, offset: Int) -> (() -> Void)? {
        let ids = visibleApps.compactMap(\.persistenceID)
        guard let id = app.persistenceID,
              arrangement.neighbor(of: id, offset: offset, visibleIDs: ids) != nil else { return nil }
        return {
            updateArrangement {
                $0.move(id, offset: offset, visibleIDs: visibleApps.compactMap(\.persistenceID))
            }
        }
    }

    /// Appearance KVO and the system-colors notification can fire in bursts
    /// without the accent actually changing, and every revision bump re-renders
    /// (and, before macOS 26, recreates) every slider row — so compare the
    /// accent resolved against the current appearance and only then re-tint.
    /// When the accent cannot be resolved this fails open (always re-tints),
    /// never closed: eating a real accent change would leave stale sliders.
    private func refreshSliderTint() {
        var resolved: NSColor?
        NSApplication.shared.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = NSColor.controlAccentColor.usingColorSpace(.sRGB)
        }
        if let resolved, let last = lastResolvedAccent, resolved == last { return }
        lastResolvedAccent = resolved
        normalSliderTint = Color(nsColor: .controlAccentColor)
        accentRevision += 1
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

    private var localDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter { $0.isBuiltIn && !$0.isAirPlay }
    }

    private var bluetoothAndHeadphoneDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter { ($0.isHeadphones || $0.isBluetooth) && !$0.isAirPlay }
    }

    private var otherDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter {
            !$0.isBuiltIn && !$0.isHeadphones && !$0.isBluetooth && !$0.isAirPlay
        }
    }

    private var hasAirPlay: Bool {
        AirPlayRouteManager.isListed || mixer.outputDevices.contains(where: \.isAirPlay)
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
            .overlay(alignment: .bottomLeading) {
                if app.isPlaying {
                    Circle()
                        .fill(PanelMetricColor.green(for: colorScheme))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1))
                        .offset(x: -1, y: 1)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isPinned || (isHovered && app.persistenceID != nil) {
                    pinBadge
                        .offset(x: 3, y: 3)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPinned)
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    /// Always a solid disc, so it reads as a badge in both states: orange
    /// with a filled pin once pinned, neutral grey with an outline pin while
    /// it only offers pinning on hover. The disc's colour and the glyph cross
    /// over in place rather than swapping one badge for another.
    private var pinBadge: some View {
        Image(systemName: isPinned ? "pin.fill" : "pin")
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 16, height: 16)
            .background(Circle().fill(isPinned ? Color.orange : Color(nsColor: .systemGray)))
            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
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

/// The options under the routing, shared with the island's mixer page so
/// both surfaces offer the same switches: idle rows, the headphone guard, the
/// precise roller, the output switcher and the hidden apps.
struct MixerOptionsControls: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var preciseVolumeRoller = PreciseVolumeRollerService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.mixerHideInactiveApps)
    private var hideInactiveApps = false
    @AppStorage(DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect)
    private var lowerOnHeadphonesDisconnect = false
    @AppStorage(DefaultsKey.mixerHeadphonesDisconnectVolumePercent)
    private var headphonesDisconnectVolumePercent = Defaults.defaultMixerHeadphonesDisconnectVolumePercent
    @AppStorage(DefaultsKey.preciseVolumeRollerEnabled)
    private var preciseVolumeRollerEnabled = false
    @State private var showListChooser = false
    var includeSharedAudioFeatures = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if AppVolumeMixer.isSupported {
                inactiveAppsVisibilityToggle
            }
            headphoneDisconnectProtectionToggle
            preciseVolumeRollerToggle
            if includeSharedAudioFeatures, AppFeature.soundOutputSwitcher.isAvailable {
                SoundOutputSwitcherControls()
            }
            if includeSharedAudioFeatures, AppFeature.audioPriority.isAvailable {
                AudioPriorityDisclosure()
            }
            if AppVolumeMixer.isSupported, !listChoices.isEmpty {
                listVisibilityFooter
            }
        }
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var headphoneDisconnectProtectionToggle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(l10n.s.mixerLowerOnHeadphonesDisconnect,
                   isOn: $lowerOnHeadphonesDisconnect.animation(reduceMotion ? nil : .settingsExpansion))
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .medium))

            Text(l10n.s.mixerLowerOnHeadphonesDisconnectCaption)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if lowerOnHeadphonesDisconnect {
                HStack(spacing: 8) {
                    Stepper(value: headphonesDisconnectVolumeBinding,
                            in: Defaults.minimumMixerHeadphonesDisconnectVolumePercent...100,
                            step: 5) {
                        Text(l10n.s.mixerHeadphonesDisconnectVolume)
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .controlSize(.small)
                    Spacer(minLength: 6)
                    Text("\(headphonesDisconnectDisplayPercent)%")
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    private var headphonesDisconnectVolumeBinding: Binding<Int> {
        Binding(
            get: { Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent) },
            set: { headphonesDisconnectVolumePercent = Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent($0) }
        )
    }

    private var headphonesDisconnectDisplayPercent: Int {
        Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent)
    }

    private var preciseVolumeRollerToggle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(l10n.s.preciseVolumeRollerEnable, isOn: $preciseVolumeRollerEnabled.animation(reduceMotion ? nil : .settingsExpansion))
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .medium))
                .onChange(of: preciseVolumeRollerEnabled) { _, enabled in
                    if enabled { permissions.requestAccessibility() }
                    PreciseVolumeRollerService.shared.syncWithPreferences()
                }

            Text(l10n.s.preciseVolumeRollerCaption)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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

    /// One entry per app the list knows about: visible rows checked, hidden
    /// apps unchecked, everything in one alphabetical run so the menu reads
    /// like the list itself.
    private struct MixerListChoice: Identifiable {
        let id: String
        let name: String
        let isListed: Bool
        /// A row with nothing stable to remember it by cannot be hidden; it
        /// still shows here so the menu mirrors the list.
        let canToggle: Bool
    }

    private var listChoices: [MixerListChoice] {
        // The hidden list updates the moment a box is unchecked, while the
        // visible rows only change when the next HAL refresh lands. Keyed by
        // persistence id with the hidden entry winning, a just-hidden app
        // shows up once (unchecked) instead of twice during that gap.
        var seen = Set<String>()
        var choices = mixer.hiddenApps.map { hidden -> MixerListChoice in
            seen.insert(hidden.id)
            return MixerListChoice(id: hidden.id, name: hidden.name, isListed: false, canToggle: true)
        }
        for app in mixer.apps {
            let id = app.persistenceID ?? app.id
            guard seen.insert(id).inserted else { continue }
            choices.append(MixerListChoice(id: id, name: app.name,
                                           isListed: true, canToggle: app.persistenceID != nil))
        }
        choices.sort {
            MixerRoutingSupport.displayOrderedBefore(name: $0.name, id: $0.id,
                                                     otherName: $1.name, otherID: $1.id)
        }
        return choices
    }

    /// Which apps the list shows (issue #300): the row reads how many are
    /// hidden and opens a check per app, right in the panel so several can be
    /// checked or unchecked in one go. Hidden apps stay here even while they
    /// are not running, so they can always be brought back.
    private var listVisibilityFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showListChooser.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(l10n.s.mixerVisibleApps)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Text(mixer.hiddenApps.isEmpty
                         ? l10n.s.mixerAllShown
                         : "\(l10n.s.mixerHiddenCountLabel): \(mixer.hiddenApps.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showListChooser ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.s.mixerVisibleApps)
            .accessibilityValue(mixer.hiddenApps.isEmpty
                                ? l10n.s.mixerAllShown
                                : "\(l10n.s.mixerHiddenCountLabel): \(mixer.hiddenApps.count)")

            if showListChooser {
                ForEach(listChoices) { choice in
                    Toggle(isOn: listedBinding(for: choice)) {
                        Text(choice.name)
                            .font(.system(size: 10.5))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .disabled(!choice.canToggle)
                }
            }
        }
    }

    private func listedBinding(for choice: MixerListChoice) -> Binding<Bool> {
        Binding(
            get: { choice.isListed },
            set: { listed in
                if listed {
                    mixer.showInList(id: choice.id)
                } else if let app = mixer.apps.first(where: { ($0.persistenceID ?? $0.id) == choice.id }) {
                    mixer.hideFromList(app)
                }
            }
        )
    }

    private var inactiveAppsVisibilityToggle: some View {
        let label = FeatureStrings.mixer(l10n.language).hideInactiveApps
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Toggle(label, isOn: $hideInactiveApps)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityLabel(label)
        }
    }
}

private struct MixerRow: View {
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    let app: MixerApp
    let normalTint: Color
    let accentRevision: Int
    let glassEnabled: Bool
    @Binding var editingVolumeID: String?
    let isPinned: Bool
    let togglePin: () -> Void
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?

    private var arrangementStrings: MixerFeatureStrings { FeatureStrings.mixer(l10n.language) }
    private var sharingStrings: MixerScreenSharingStrings { .localized(l10n.language) }

    /// Warm accent to flag the boost range, darkened in Light Mode for contrast.
    private var boostColor: Color { PanelMetricColor.orange(for: colorScheme) }
    /// Tie the visual state to the displayed percentage, so "amber" and ">100%"
    /// always agree and the reset hides exactly when the row reads 100%.
    private var isBoosting: Bool { (app.volume * 100).rounded() > 100 }
    private var isAtUnity: Bool { (app.volume * 100).rounded() == 100 }

    /// SoundSource-sized icon spanning the row's two lines (issue #166); the
    /// bitmap must be requested at this size or the upscale looks blurry.
    private static let iconPointSize: CGFloat = 32

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid,
                                                       pointSize: Self.iconPointSize))
                    .resizable()
                    .frame(width: Self.iconPointSize, height: Self.iconPointSize)
                if app.isPlaying {
                    Circle()
                        .fill(PanelMetricColor.green(for: colorScheme))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.2))
                        .offset(x: -1, y: -1)
                }
            }
            .help(arrangementStrings.arrange)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(arrangementStrings.arrange)

                    Spacer(minLength: 4)

                    if app.persistenceID != nil {
                        MixerPinButton(isPinned: isPinned, pinTitle: arrangementStrings.pin,
                                       unpinTitle: arrangementStrings.unpin, appName: app.name, action: togglePin)
                    }
                    if !app.isBypassed {
                        outputPicker
                    }
                }

                if app.isBypassed {
                    Text(app.supportsVolumeOverride ? sharingStrings.protectedCaption : l10n.s.mixerBypassedCaption)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(app.supportsVolumeOverride ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 8) {
                        MixerVolumeSlider(value: volumeBinding,
                                          normalTint: normalTint,
                                          boostTint: boostColor,
                                          isBoosting: isBoosting,
                                          accentRevision: accentRevision,
                                          maximum: AppVolumeMixer.maxVolume,
                                          accessibilityLabel: app.name)

                        EditableVolumePercent(currentPercent: Int((app.volume * 100).rounded()),
                                              maximumPercent: Int(AppVolumeMixer.maxVolume * 100),
                                              width: 42,
                                              editorID: "app:\(app.id)",
                                              editingID: $editingVolumeID,
                                              accessibilityLabel: app.name) {
                            HStack(spacing: 2) {
                                if isBoosting {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(boostColor)
                                }
                                Text("\(Int((app.volume * 100).rounded()))%")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(isBoosting ? boostColor : Color.secondary)
                            }
                        } onCommit: {
                            mixer.setVolume($0, for: app)
                        }

                        Button {
                            mixer.setVolume(1, for: app)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(isBoosting ? boostColor : Color.secondary)
                                .frame(width: 14)
                        }
                        .buttonStyle(.plain)
                        .help(l10n.s.mixerResetTooltip)
                        .opacity(isAtUnity ? 0 : 1)
                        .disabled(isAtUnity)

                        Button {
                            mixer.toggleMute(app)
                        } label: {
                            Image(systemName: app.volume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(app.volume <= 0.001
                                                 ? PanelMetricColor.red(for: colorScheme)
                                                 : Color.secondary)
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)
                    }

                    if app.supportsVolumeOverride {
                        Label(sharingStrings.sharingWarning, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if app.outputDeviceUnavailable {
                        Label(l10n.s.mixerOutputFallback, systemImage: "speaker.badge.exclamationmark")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityAction(named: Text(arrangementStrings.moveUp)) { moveUp?() }
        .accessibilityAction(named: Text(arrangementStrings.moveDown)) { moveDown?() }
        .contextMenu {
            if app.persistenceID != nil {
                arrangementActions
                Divider()
                Button(l10n.s.mixerHideFromList) {
                    mixer.hideFromList(app)
                }
            }
        }
    }

    @ViewBuilder
    private var arrangementActions: some View {
        Button(action: togglePin) {
            Label(isPinned ? arrangementStrings.unpin : arrangementStrings.pin,
                  systemImage: isPinned ? "pin.slash" : "pin")
        }
        if app.supportsVolumeOverride {
            Divider()
            Toggle(sharingStrings.allowVolumeControl, isOn: Binding(
                get: { !app.isBypassed },
                set: { mixer.setCallAppVolumeControl($0, for: app) }))
                .help(sharingStrings.sharingWarning)
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { app.volume },
            set: { mixer.setVolume($0, for: app) }
        )
    }

    private var outputPicker: some View {
        Picker(l10n.s.mixerOutputTooltip, selection: outputSelectionBinding) {
            Text(l10n.s.mixerOutputDefault)
                .tag(MixerRoutingSupport.systemDefaultSelectionID)
            ForEach(mixer.outputDevices.filter { !MixerRoutingSupport.isAirPlaySentinel($0.uid) }) { device in
                Text(outputDeviceTitle(device))
                    .tag(device.uid)
            }
            if let selected = app.selectedOutputDeviceUID,
               MixerRoutingSupport.needsUnavailableOutputRow(selectedUID: selected,
                                                             isUnavailable: app.outputDeviceUnavailable,
                                                             listedUIDs: mixer.outputDevices.map(\.uid)) {
                Text(l10n.s.mixerOutputUnavailable)
                    .tag(selected)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: 112)
        .help(l10n.s.mixerOutputTooltip)
    }

    private var outputSelectionBinding: Binding<String> {
        Binding(
            get: { app.selectedOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                mixer.setOutputDeviceUID(selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection,
                                         for: app)
            }
        )
    }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.name
    }
}

/// The Audio priority disclosure shown inside the shared audio device card.
struct AudioPriorityDisclosure: View {
    @ObservedObject private var l10n = L10n.shared
    private let showsHeader: Bool
    @State private var expanded: Bool

    init(initiallyExpanded: Bool = false, showsHeader: Bool = true) {
        self.showsHeader = showsHeader
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "list.number")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(l10n.s.audioPrioritySection)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n.s.audioPriorityCaption)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    AudioOutputPriorityControls()
                    Divider()
                    AudioInputPriorityControls()
                }
                .padding(.leading, showsHeader ? 19 : 0)
            }
        }
    }
}

/// The percentage keeps its compact read-only appearance until clicked, then
/// becomes a selected text field so the next keystroke replaces the old value.
