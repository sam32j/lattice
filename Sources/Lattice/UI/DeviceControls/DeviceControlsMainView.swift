// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Main page for Device Controls combining Display Brightness, Keyboard Backlight,
/// Audio Output, and Audio Input into compact grouped sections.
struct DeviceControlsMainView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var navigation = DeviceControlsNavigationState.shared

    private var activeAppCount: Int {
        mixer.apps.filter {
            MixerRoutingSupport.shouldShowApp(
                isPlaying: $0.isPlaying,
                volume: $0.volume,
                selectedOutputDeviceUID: $0.selectedOutputDeviceUID,
                hideInactiveApps: true
            )
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            brightnessSection
            audioOutputSection
            audioInputSection
        }
        .onAppear {
            brightness.refresh()
            brightness.refreshKeyboardLight()
            mixer.refreshApps()
            inputManager.syncWithPreferences()
        }
    }

    // MARK: - Section 1: Brightness

    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(
                title: "Brightness",
                onMoreSettings: {
                    SettingsRouter.shared.request(
                        FeatureSettingsDestination(.energy, sectionAnchor: .brightness)
                    )
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                }
            )

            VStack(alignment: .leading, spacing: 8) {
                if brightness.displays.isEmpty {
                    Text(FeatureStrings.brightness(l10n.language).noDisplays)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                } else {
                    ForEach(brightness.displays) { display in
                        displayRow(display)
                    }
                }

                if brightness.keyboardLightEnabled != nil {
                    Divider()
                    keyboardRow
                }
            }
            .panelCard(padded: true)
        }
    }

    private func displayRow(_ display: BrightnessDisplay) -> some View {
        HStack(spacing: 8) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            Text(brightness.displays.count > 1 ? display.name : "Display")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 78, alignment: .leading)

            if display.isActive, display.method != nil {
                Slider(value: brightnessBinding(display), in: 0...1)
                    .controlSize(.small)
                    .disabled(brightness.isDisplayPending(display.id))
                    .accessibilityLabel(display.name)
            } else {
                Spacer()
                Text(FeatureStrings.brightness(l10n.language).displayOff)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if display.isActive, display.method != nil {
                Text("\(Int((display.brightness * 100).rounded()))%")
                    .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }

    private var keyboardRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            Text("Keyboard")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(width: 78, alignment: .leading)

            Slider(
                value: keyboardLightBinding,
                in: 0...1,
                onEditingChanged: brightness.keyboardLightDragChanged
            )
            .controlSize(.small)
            .accessibilityLabel("Keyboard backlight brightness")

            Text(keyboardLightReadout)
                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 38, alignment: .trailing)
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

    private func brightnessBinding(_ display: BrightnessDisplay) -> Binding<Double> {
        Binding(
            get: { display.brightness },
            set: { brightness.setBrightness($0, for: display.id) }
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
                    let currentlyOn = (brightness.keyboardLightLevel ?? 0) > 0
                    if currentlyOn {
                        if newValue < 0.5 {
                            brightness.setKeyboardLightEnabled(false)
                        }
                    } else {
                        if newValue > 0.0 {
                            brightness.setKeyboardLightEnabled(true)
                        }
                    }
                } else {
                    brightness.setKeyboardLightLevel(Float(newValue))
                }
            }
        )
    }

    // MARK: - Section 2: Audio Output

    private var audioOutputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(
                title: "Audio Output",
                onMoreSettings: {
                    SettingsRouter.shared.request(
                        FeatureSettingsDestination(.audioOutput, sectionAnchor: .mixer)
                    )
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                }
            )

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Output device selector
                outputDeviceRow

                // Row 2: Output volume slider
                outputVolumeRow

                // Row 3: App Volumes navigation row (NO separator between Volume and App Volumes)
                appVolumesNavigationRow

                // Subtle divider above System Sounds
                Divider()

                // Row 4: System Sounds output selector
                systemSoundsRow
            }
            .panelCard(padded: true)
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

    private var outputVolumeRow: some View {
        HStack(spacing: 8) {
            Button {
                if let muted = mixer.systemOutputMuted {
                    mixer.requestOutputAdjustment(muted: !muted)
                }
            } label: {
                Image(systemName: mixer.systemOutputMuted == true || (mixer.systemOutputVolume ?? 0) <= 0.001
                      ? "speaker.slash.fill"
                      : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(mixer.systemOutputMuted == true ? Color.red : Color.secondary)
                    .frame(width: 18, alignment: .center)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mixer.systemOutputMuted == true ? "Unmute output" : "Mute output")

            Text("Volume")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            DeviceControlsSlider(
                title: "Volume",
                value: systemOutputVolumeBinding,
                range: 0...1,
                step: 0.01,
                readout: "\(Int(((mixer.systemOutputVolume ?? 0) * 100).rounded()))%"
            )
        }
    }

    private var appVolumesNavigationRow: some View {
        Button {
            navigation.currentSubpage = .appVolumes
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

    private var systemOutputVolumeBinding: Binding<Double> {
        Binding(
            get: { mixer.systemOutputVolume ?? 0 },
            set: { mixer.setCurrentOutputVolume($0) }
        )
    }

    // MARK: - Section 3: Audio Input

    private var audioInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(
                title: "Audio Input",
                onMoreSettings: {
                    SettingsRouter.shared.request(
                        FeatureSettingsDestination(.audioInput, sectionAnchor: .audioPriority)
                    )
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                }
            )

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Microphone selector
                microphoneRow

                Divider()

                // Row 2: Input level control
                inputLevelRow
            }
            .panelCard(padded: true)
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

    private var inputLevelRow: some View {
        let hasVolume = inputManager.inputVolume != nil
        let volume = inputManager.inputVolume ?? 1.0
        return HStack(spacing: 8) {
            Image(systemName: micMute.isMuted || (hasVolume && volume <= 0.001) ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)

            Text("Input level")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            DeviceControlsSlider(
                title: "Input level",
                value: inputVolumeBinding,
                range: 0...1,
                step: 0.01,
                readout: "\(Int((volume * 100).rounded()))%"
            )
            .disabled(!hasVolume || micMute.isMuted)
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

    private var inputVolumeBinding: Binding<Double> {
        Binding(
            get: { inputManager.inputVolume ?? 1.0 },
            set: { inputManager.setInputVolume($0) }
        )
    }

    // MARK: - Section Header Component

    private func sectionHeader(title: String, onMoreSettings: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Button("More settings…", action: onMoreSettings)
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}
