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
            DeviceControlsBrightnessSection(brightnessControlEnabled: brightnessControlEnabled)
            if volumeMixerEnabled {
                DeviceControlsAudioOutputSection()
            }
            if microphoneControlEnabled {
                DeviceControlsAudioInputSection()
            }
        }
        .onAppear {
            let brightness = BrightnessService.shared
            if brightnessControlEnabled, brightness.displays.isEmpty {
                brightness.refresh()
            }
            brightness.refreshKeyboardLight()
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
    @State private var lastUnmutedOutputVolume: Double = {
        let saved = UserDefaults.standard.object(forKey: "audioOutputLastUnmutedVolume") as? Double ?? 0.5
        return saved > 0.001 ? saved : 0.5
    }()
    @State private var draggingOutputVolume: Double? = nil
    /// While dragging, writes skip publishing on the shared mixer (see
    /// `requestOutputAdjustment(publishes:)`); the final level publishes on release.
    @State private var editingOutputVolume = false

    private var isSystemOutputMuted: Bool {
        if let draggingOutputVolume {
            return draggingOutputVolume <= 0.001
        }
        return mixer.systemOutputMuted == true || (mixer.systemOutputVolume ?? 0) <= 0.001
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
                    } else {
                        editingOutputVolume = false
                        if let finalVol = draggingOutputVolume {
                            publishFinalOutputVolume(finalVol)
                            if finalVol > 0.001 {
                                UserDefaults.standard.set(finalVol, forKey: "audioOutputLastUnmutedVolume")
                            }
                        }
                        draggingOutputVolume = nil
                    }
                }
            )
            .frame(width: 155)
        }
    }

    private func toggleOutputMute() {
        NotchService.shared.noteOwnLevelAdjustment(.volume)
        let currentlyMuted = mixer.systemOutputMuted == true || (mixer.systemOutputVolume ?? 0) <= 0.001
        if currentlyMuted {
            let restoreVal = lastUnmutedOutputVolume > 0.001 ? lastUnmutedOutputVolume : (mixer.systemOutputVolume ?? 0.5)
            let finalVal = restoreVal > 0.001 ? restoreVal : 0.5
            mixer.requestOutputAdjustment(volume: finalVal, muted: false)
        } else {
            if let cur = mixer.systemOutputVolume, cur > 0.001 {
                lastUnmutedOutputVolume = cur
                UserDefaults.standard.set(cur, forKey: "audioOutputLastUnmutedVolume")
            }
            mixer.requestOutputAdjustment(muted: true)
        }
    }

    private func publishFinalOutputVolume(_ volume: Double) {
        if mixer.systemOutputMuted == true, volume > 0.001 {
            mixer.requestOutputAdjustment(volume: volume, muted: false)
        } else {
            mixer.requestOutputAdjustment(volume: volume)
        }
    }

    private var systemOutputVolumeBinding: Binding<Double> {
        Binding(
            get: { draggingOutputVolume ?? displayedSystemOutputVolume },
            set: { newValue in
                draggingOutputVolume = newValue
                NotchService.shared.noteOwnLevelAdjustment(.volume)
                if newValue > 0.001 { lastUnmutedOutputVolume = newValue }
                if mixer.systemOutputMuted == true, newValue > 0.001 {
                    mixer.requestOutputAdjustment(volume: newValue, muted: false,
                                                  publishes: !editingOutputVolume)
                } else {
                    mixer.requestOutputAdjustment(volume: newValue, publishes: !editingOutputVolume)
                }
            }
        )
    }
}

// MARK: - Section 3: Audio Input

private struct DeviceControlsAudioInputSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DeviceControlsSectionHeader(title: "Audio Input")

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Microphone selector
                microphoneRow

                // Row 2: Input level control
                DeviceControlsInputLevelRow()
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
    @State private var lastUnmutedInputVolume: Double = {
        let saved = UserDefaults.standard.object(forKey: "audioInputLastUnmutedVolume") as? Double ?? 0.75
        return saved > 0.001 ? saved : 0.75
    }()
    @State private var draggingInputVolume: Double? = nil
    @State private var unmutingFromDrag = false

    private var isInputMuted: Bool {
        if let draggingInputVolume {
            return draggingInputVolume <= 0.001
        }
        return micMute.isMuted || (inputManager.inputVolume != nil && (inputManager.inputVolume ?? 0) <= 0.001)
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
                AnimatedMicMuteSymbol(muted: isInputMuted, fontSize: 11)
                    .equatable()
                    .foregroundStyle(isInputMuted ? Color.red : Color.secondary)
                    .animation(.easeInOut(duration: 0.22), value: isInputMuted)
                    .frame(width: 18, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isInputMuted ? l10n.s.actionUnmute : l10n.s.actionMute)

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
                        if let finalVol = draggingInputVolume, finalVol > 0.001 {
                            UserDefaults.standard.set(finalVol, forKey: "audioInputLastUnmutedVolume")
                            if !micMute.isMuted {
                                inputManager.setInputVolume(finalVol)
                            }
                        }
                        draggingInputVolume = nil
                        unmutingFromDrag = false
                    }
                }
            )
            .frame(width: 155)
            .disabled(!hasVolume)
        }
        .onChange(of: micMute.isMuted) { _, muted in
            if !muted {
                unmutingFromDrag = false
                if let pending = draggingInputVolume, pending > 0.001 {
                    inputManager.setInputVolume(pending)
                }
            }
        }
    }

    private func toggleInputMute() {
        let currentlyMuted = micMute.isMuted || (inputManager.inputVolume != nil && (inputManager.inputVolume ?? 0) <= 0.001)
        if currentlyMuted {
            let restoreVal = lastUnmutedInputVolume > 0.001 ? lastUnmutedInputVolume : (inputManager.inputVolume ?? 0.75)
            let finalVal = restoreVal > 0.001 ? restoreVal : 0.75
            var saved = UserDefaults.standard.dictionary(forKey: DefaultsKey.micMuteSavedVolumes) as? [String: Double] ?? [:]
            if let uid = inputManager.effectiveInputDeviceUID {
                saved[uid] = finalVal
                UserDefaults.standard.set(saved, forKey: DefaultsKey.micMuteSavedVolumes)
            }
            micMute.setMuted(false)
            inputManager.setInputVolume(finalVal)
        } else {
            if let cur = inputManager.inputVolume, cur > 0.001 {
                lastUnmutedInputVolume = cur
                UserDefaults.standard.set(cur, forKey: "audioInputLastUnmutedVolume")
            }
            micMute.setMuted(true)
        }
    }

    private var inputVolumeBinding: Binding<Double> {
        Binding(
            get: { draggingInputVolume ?? displayedInputVolume },
            set: { newValue in
                draggingInputVolume = newValue
                if newValue > 0.001 {
                    lastUnmutedInputVolume = newValue
                }
                if micMute.isMuted, newValue > 0.001 {
                    if !unmutingFromDrag {
                        unmutingFromDrag = true
                        var saved = UserDefaults.standard.dictionary(forKey: DefaultsKey.micMuteSavedVolumes) as? [String: Double] ?? [:]
                        if let uid = inputManager.effectiveInputDeviceUID {
                            saved[uid] = newValue
                            UserDefaults.standard.set(saved, forKey: DefaultsKey.micMuteSavedVolumes)
                        }
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
