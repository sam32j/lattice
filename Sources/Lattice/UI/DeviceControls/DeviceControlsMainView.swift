// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Main page for Device Controls combining Display Brightness, Keyboard Backlight,
/// Audio Output, and Audio Input into compact grouped sections.
struct DeviceControlsMainView: View {
    @ObservedObject private var navigation = DeviceControlsNavigationState.shared
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessControlEnabled = false
    @AppStorage(DefaultsKey.volumeMixerEnabled) private var volumeMixerEnabled = true
    @AppStorage(DefaultsKey.microphoneLevelControlEnabled) private var microphoneControlEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if brightnessControlEnabled || BrightnessService.keyboardLightIsSupported {
                DeviceControlsBrightnessSection(brightnessControlEnabled: brightnessControlEnabled)
            }
            if volumeMixerEnabled {
                DeviceControlsAudioOutputSection()
            }
            if microphoneControlEnabled {
                DeviceControlsAudioInputSection()
            }
        }
        .onAppear {
            if brightnessControlEnabled || BrightnessService.keyboardLightIsSupported {
                let brightness = BrightnessService.shared
                if brightnessControlEnabled, brightness.displays.isEmpty {
                    brightness.refresh()
                }
                brightness.refreshKeyboardLight()
            }
            if volumeMixerEnabled, AppVolumeMixer.shared.outputDevices.isEmpty {
                AppVolumeMixer.shared.refreshApps()
            }
            if microphoneControlEnabled, AudioInputDeviceManager.shared.inputDevices.isEmpty {
                AudioInputDeviceManager.shared.syncWithPreferences()
            }
        }
        .onChange(of: brightnessControlEnabled) { _, enabled in
            if enabled {
                BrightnessService.shared.refresh()
            }
        }
        .onChange(of: volumeMixerEnabled) { _, enabled in
            if !enabled, navigation.currentSubpage == .appVolumes {
                navigation.resetSubpage()
            }
        }
    }
}

// MARK: - Section 1: Brightness

private struct DeviceControlsBrightnessSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared
    let brightnessControlEnabled: Bool

    private var hasVisibleDisplayRows: Bool {
        brightnessControlEnabled && !brightness.displays.isEmpty
    }

    var body: some View {
        if hasVisibleDisplayRows || brightness.keyboardLightEnabled != nil {
            VStack(alignment: .leading, spacing: 6) {
                DeviceControlsSectionHeader(title: "Brightness")

                VStack(alignment: .leading, spacing: 8) {
                    if hasVisibleDisplayRows {
                        ForEach(brightness.displays) { display in
                            DeviceControlsDisplayBrightnessRow(
                                display: display,
                                showDisplayName: brightness.displays.count > 1,
                                isPending: brightness.isDisplayPending(display.id)
                            )
                        }
                    }

                    if brightness.keyboardLightEnabled != nil {
                        if hasVisibleDisplayRows {
                            Divider()
                        }
                        DeviceControlsKeyboardLightRow()
                    }
                }
                .panelCard(interactive: false, padded: true)
            }
        }
    }
}

private struct DeviceControlsDisplayBrightnessRow: View {
    @ObservedObject private var l10n = L10n.shared
    let display: BrightnessDisplay
    let showDisplayName: Bool
    let isPending: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            Text(showDisplayName ? display.name : "Display")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            if display.isActive, display.method != nil {
                DeviceControlsSlider(
                    title: display.name,
                    value: Binding(
                        get: { display.brightness },
                        set: { BrightnessService.shared.setBrightness($0, for: display.id, announces: false) }
                    ),
                    range: 0...1,
                    step: 0
                )
                .frame(width: 155)
                .disabled(isPending)
            } else {
                Text(FeatureStrings.brightness(l10n.language).displayOff)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 155, alignment: .trailing)
            }
        }
    }
}

private struct DeviceControlsKeyboardLightRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared

    private var isLit: Bool {
        (brightness.keyboardLightLevel ?? 0) > 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                brightness.setKeyboardLightEnabled(!isLit)
            } label: {
                Image(systemName: isLit ? "keyboard.fill" : "keyboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isLit ? Color.primary : Color.secondary)
                    .frame(width: 18, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle keyboard backlight")

            Text("Keyboard")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            DeviceControlsSlider(
                title: "Keyboard",
                value: keyboardLightBinding,
                range: 0...1,
                step: brightness.keyboardLightSaturated ? 1.0 : 0,
                readout: brightness.keyboardLightSaturated ? keyboardLightReadout : nil,
                onEditingChanged: brightness.keyboardLightDragChanged
            )
            .frame(width: 155)
        }
    }

    private var keyboardLightReadout: String {
        let hubStrings = FeatureStrings.keepAwakeHub(l10n.language)
        return BrightnessSupport.keyboardLightDisplayReadout(
            level: brightness.keyboardLightLevel,
            isSaturated: brightness.keyboardLightSaturated,
            onText: hubStrings.on,
            offText: hubStrings.off
        )
    }

    private var keyboardLightBinding: Binding<Double> {
        Binding(
            get: {
                BrightnessSupport.keyboardLightDisplayLevel(
                    level: brightness.keyboardLightLevel,
                    isSaturated: brightness.keyboardLightSaturated
                )
            },
            set: { newValue in
                if brightness.keyboardLightSaturated {
                    let shouldBeOn = newValue >= 0.5
                    if shouldBeOn != isLit {
                        brightness.setKeyboardLightEnabled(shouldBeOn)
                    }
                } else {
                    brightness.setKeyboardLightLevel(Float(newValue))
                }
            }
        )
    }
}

// MARK: - Section 2: Audio Output

private struct DeviceControlsAudioOutputSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared

    private var activeAppCount: Int {
        mixer.apps.reduce(into: 0) { count, app in
            if DeviceControlsAppVolumesLayout.isActive(app) { count += 1 }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DeviceControlsSectionHeader(title: "Audio Output")

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Output device selector
                outputDeviceRow

                // Row 2: Output volume slider
                DeviceControlsOutputVolumeRow()

                // Row 3: App Volumes navigation row (NO separator between Volume and App Volumes)
                appVolumesNavigationRow

                // Subtle divider above System Sounds
                Divider()

                // Row 4: System Sounds output selector
                systemSoundsRow
            }
            .panelCard(interactive: false, padded: true)
        }
    }

    private var outputDeviceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            Text("Output")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Picker("Output", selection: universalOutputSelectionBinding) {
                if mixer.currentOutputDeviceUID == nil {
                    Text(l10n.s.mixerOutputUnavailable)
                        .tag(MixerRoutingSupport.systemDefaultSelectionID)
                }
                ForEach(universalOutputDevices) { device in
                    Text(device.name)
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

    private var appVolumesNavigationRow: some View {
        Button {
            NotchService.shared.showDeviceControlsSubpage(.appVolumes)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .center)

                Text("App Volumes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(activeAppCount) active")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 1)
        .accessibilityLabel("App Volumes, \(activeAppCount) active")
    }

    private var systemSoundsRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            Text("System Sounds")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(minWidth: 105, alignment: .leading)

            Spacer(minLength: 6)

            Picker("System Sounds", selection: systemSoundOutputSelectionBinding) {
                if mixer.currentSystemSoundOutputDeviceUID == nil {
                    Text(l10n.s.mixerOutputUnavailable)
                        .tag(MixerRoutingSupport.systemDefaultSelectionID)
                }
                ForEach(systemSoundOutputDevices) { device in
                    Text(device.name)
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
}

private struct DeviceControlsOutputVolumeRow: View {
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @State private var draggingOutputVolume: Double? = nil
    /// While dragging, writes skip publishing on the shared mixer (see
    /// `requestOutputAdjustment(publishes:)`); the final level publishes on release.
    @State private var editingOutputVolume = false
    /// The output a drag started on. Should the output change before release
    /// (headphones unplugged), the drag belonged to the old one and is dropped.
    @State private var editingOutputUID: String?
    /// Set when the output changes at any point in a drag, so a round trip
    /// back to the first output still drops the drag.
    @State private var outputChangedDuringEdit = false

    private var isSystemOutputMuted: Bool {
        if let draggingOutputVolume {
            return draggingOutputVolume <= 0.001
        }
        return mixer.outputReadsMuted
    }

    private var displayedSystemOutputVolume: Double {
        if let draggingOutputVolume { return draggingOutputVolume }
        if mixer.systemOutputMuted == true { return 0 }
        return mixer.systemOutputVolume ?? 0
    }

    private var speakerVariableValue: Double {
        let v = displayedSystemOutputVolume
        if v <= 0.001 { return 0 }
        if v < 0.34 { return 0.25 }
        if v < 0.67 { return 0.6 }
        return 1.0
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggleOutputMute()
            } label: {
                Group {
                    if isSystemOutputMuted {
                        Image(systemName: "speaker.fill")
                    } else {
                        Image(systemName: "speaker.wave.3.fill", variableValue: speakerVariableValue)
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSystemOutputMuted ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                .frame(width: 18, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSystemOutputMuted ? "Unmute output" : "Mute output")

            Text("Volume")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            DeviceControlsSlider(
                title: "Volume",
                value: systemOutputVolumeBinding,
                range: 0...1,
                step: 0,
                onEditingChanged: { editing in
                    if editing {
                        editingOutputVolume = true
                        editingOutputUID = mixer.currentOutputDeviceUID
                        outputChangedDuringEdit = false
                    } else {
                        editingOutputVolume = false
                        let sameOutput = !outputChangedDuringEdit && editingOutputUID == mixer.currentOutputDeviceUID
                        editingOutputUID = nil
                        outputChangedDuringEdit = false
                        if sameOutput, let finalVol = draggingOutputVolume {
                            mixer.requestOutputLevel(finalVol)
                            if finalVol > 0.001 {
                                UserDefaults.standard.set(finalVol, forKey: AppVolumeMixer.lastUnmutedOutputVolumeKey)
                            }
                        }
                        draggingOutputVolume = nil
                    }
                }
            )
            // No scalar level on this output: nothing for the slider to set.
            // Mute stays available on its own button.
            .disabled(mixer.systemOutputVolume == nil)
            // A draft belongs to the output it was made on: another output
            // shows its own level and mute at once.
            .onChange(of: mixer.currentOutputDeviceUID) { _, _ in
                if editingOutputVolume { outputChangedDuringEdit = true }
                draggingOutputVolume = nil
            }
            .frame(width: 155)
        }
    }

    private func toggleOutputMute() {
        NotchService.shared.noteOwnLevelAdjustment(.volume)
        mixer.togglePanelOutputMute()
    }

    private var systemOutputVolumeBinding: Binding<Double> {
        Binding(
            get: { draggingOutputVolume ?? displayedSystemOutputVolume },
            set: { newValue in
                if editingOutputVolume, outputChangedDuringEdit || editingOutputUID != mixer.currentOutputDeviceUID {
                    draggingOutputVolume = nil
                    return
                }
                draggingOutputVolume = newValue
                NotchService.shared.noteOwnLevelAdjustment(.volume)
                mixer.requestOutputLevel(newValue, publishes: !editingOutputVolume)
            }
        )
    }
}

// MARK: - Section 3: Audio Input

private struct DeviceControlsAudioInputSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared
    @ObservedObject private var micMute = MicMuteService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DeviceControlsSectionHeader(title: "Audio Input")

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Microphone selector
                microphoneRow

                // Row 2: Input level control
                DeviceControlsInputLevelRow()

                if micMute.warning == .manualRestore {
                    HStack(alignment: .center, spacing: 8) {
                        Label(MicMuteService.Warning.manualRestore.message, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(l10n.s.micManualRestoreChecked) {
                            micMute.acknowledgeManualRestore()
                        }
                        .controlSize(.small)
                        .fixedSize()
                    }
                }
            }
            .panelCard(interactive: false, padded: true)
        }
    }

    private var microphoneRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            Text("Microphone")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            if inputManager.inputDevices.isEmpty {
                Text(l10n.s.mixerInputNoDevices)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Picker("Microphone", selection: inputSelectionBinding) {
                    ForEach(inputManager.inputDevices) { device in
                        Text(device.name)
                            .tag(device.uid)
                    }
                    if let selected = inputManager.preferredInputDeviceUID,
                       inputManager.preferredUnavailable {
                        Text(l10n.s.mixerInputUnavailable)
                            .tag(selected)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 164)
                .disabled(inputManager.inputDevices.isEmpty)
            }
        }
    }

    private var inputSelectionBinding: Binding<String> {
        Binding(
            get: {
                inputManager.currentInputDeviceUID
                    ?? inputManager.inputDevices.first?.uid
                    ?? ""
            },
            set: { selection in
                inputManager.setCurrentInputDeviceUID(selection)
            }
        )
    }
}

private struct DeviceControlsInputLevelRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @State private var draggingInputVolume: Double? = nil
    @State private var unmutingFromDrag = false
    @State private var pendingUnmuteLevel: PendingInputUnmuteLevel?
    /// The audible level a drag started from, remembered for Unmute when the
    /// drag ends at zero.
    @State private var levelBeforeEdit: Double?
    /// The input an edit started on; a switch to another input mid-edit drops
    /// the edit rather than handing its level to the new one.
    @State private var editInputUID: String??
    /// Set once an edit is dropped for a switched input; its remaining ticks
    /// are ignored until the slider is released.
    @State private var editDropped = false

    private var isInputMuted: Bool {
        if let draggingInputVolume {
            return draggingInputVolume == 0
        }
        return micMute.isMuted || inputManager.inputVolume == 0
    }

    private var displayedInputVolume: Double {
        if let draggingInputVolume { return draggingInputVolume }
        if micMute.isMuted { return 0 }
        return inputManager.inputVolume ?? 1.0
    }

    var body: some View {
        let hasVolume = inputManager.inputVolume != nil
        HStack(spacing: 8) {
            Button {
                toggleInputMute()
            } label: {
                AnimatedMicMuteSymbol(muted: isInputMuted, warning: micMute.warning != nil, fontSize: 11)
                    .equatable()
                    .foregroundStyle(micMute.warning != nil ? Color.orange : isInputMuted ? Color.red : Color.secondary)
                    .animation(.easeInOut(duration: 0.22), value: isInputMuted)
                    .frame(width: 18, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(micMute.warning?.message ?? (isInputMuted ? l10n.s.actionUnmute : l10n.s.actionMute))
            .accessibilityLabel(isInputMuted ? l10n.s.actionUnmute : l10n.s.actionMute)
            .accessibilityValue(micMute.warning?.message ?? "")

            Text("Input level")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            DeviceControlsSlider(
                title: "Input level",
                value: inputVolumeBinding,
                range: 0...1,
                step: 0,
                onEditingChanged: { editing in
                    if !editing {
                        finishInputEdit()
                    }
                }
            )
            .frame(width: 155)
            .disabled(!hasVolume)
        }
        .onChange(of: micMute.isMuted) { _, muted in
            guard !muted else {
                pendingUnmuteLevel = nil
                return
            }
            unmutingFromDrag = false
            if let dragging = draggingInputVolume, dragging > 0, editIsOnCurrentInput {
                pendingUnmuteLevel = nil
                inputManager.setInputVolume(dragging)
            } else if let pending = pendingUnmuteLevel {
                pendingUnmuteLevel = nil
                if pending.deviceUID == inputManager.effectiveInputDeviceUID {
                    inputManager.setInputVolume(pending.value)
                }
            }
        }
    }

    private func toggleInputMute() {
        let currentlyMuted = micMute.isMuted || inputManager.inputVolume == 0
        if currentlyMuted {
            let level = inputManager.inputUnmuteLevel
            inputManager.seedMicMuteRestore(level)
            if micMute.isMuted {
                pendingUnmuteLevel = PendingInputUnmuteLevel(deviceUID: inputManager.effectiveInputDeviceUID,
                                                             value: level)
            }
            micMute.setMuted(false)
            inputManager.setInputVolume(level)
        } else {
            if let cur = inputManager.inputVolume, cur > 0 {
                inputManager.rememberUnmutedInputVolume(cur)
            }
            micMute.setMuted(true)
        }
    }

    /// Ends a slider edit. A level chosen while the unmute it started is
    /// still in flight waits for it; a drag to zero remembers where it began.
    private var editIsOnCurrentInput: Bool {
        editInputUID.map { $0 == inputManager.effectiveInputDeviceUID } ?? true
    }

    private func finishInputEdit() {
        defer {
            draggingInputVolume = nil
            unmutingFromDrag = false
            levelBeforeEdit = nil
            editInputUID = nil
            editDropped = false
        }
        guard !editDropped, editIsOnCurrentInput else { return }
        if let finalVol = draggingInputVolume {
            if finalVol > 0 {
                inputManager.rememberUnmutedInputVolume(finalVol)
                if micMute.isMuted {
                    pendingUnmuteLevel = PendingInputUnmuteLevel(deviceUID: inputManager.effectiveInputDeviceUID,
                                                                 value: finalVol)
                } else {
                    inputManager.setInputVolume(finalVol)
                }
            } else {
                if let before = levelBeforeEdit { inputManager.rememberUnmutedInputVolume(before) }
                // The drag started an unmute and came back to zero before it
                // landed: zero is the level, applied once the unmute lifts.
                if micMute.isMuted, unmutingFromDrag {
                    pendingUnmuteLevel = PendingInputUnmuteLevel(deviceUID: inputManager.effectiveInputDeviceUID,
                                                                 value: 0)
                }
            }
        }
    }

    private var inputVolumeBinding: Binding<Double> {
        Binding(
            get: { draggingInputVolume ?? displayedInputVolume },
            set: { newValue in
                if editDropped { return }
                if draggingInputVolume == nil {
                    editInputUID = .some(inputManager.effectiveInputDeviceUID)
                    if !micMute.isMuted, let current = inputManager.inputVolume, current > 0 {
                        levelBeforeEdit = current
                    }
                } else if !editIsOnCurrentInput {
                    draggingInputVolume = nil
                    editDropped = true
                    return
                }
                draggingInputVolume = newValue
                if micMute.isMuted, newValue > 0 {
                    if !unmutingFromDrag {
                        unmutingFromDrag = true
                        inputManager.seedMicMuteRestore(newValue)
                        micMute.setMuted(false)
                    }
                } else if !unmutingFromDrag {
                    inputManager.setInputVolume(newValue)
                }
            }
        )
    }
}

// MARK: - Section Header Component

private struct DeviceControlsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
