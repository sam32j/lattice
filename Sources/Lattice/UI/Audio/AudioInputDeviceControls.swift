import AppKit
import SwiftUI

/// Shared microphone controls used by Audio Input and the live menu panel.
struct AudioInputDeviceControls: View {
    var title: String? = nil
    var levelTitle: String? = nil
    var sliderWidth: CGFloat = 140
    var showsUnavailableLabel = false
    var showsIcons: Bool = true
    @Environment(\.notchPresentation) private var inNotch
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared
    @ObservedObject private var audioPriority = AudioPriorityService.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @State private var lastUnmutedInputVolume: Double = {
        let saved = UserDefaults.standard.object(forKey: "audioInputLastUnmutedVolume") as? Double ?? 0.75
        return saved > 0.001 ? saved : 0.75
    }()
    @State private var draggingInputVolume: Double? = nil
    @State private var unmutingFromDrag = false

    var body: some View {
        VStack(alignment: .leading, spacing: showsIcons ? 8 : 14) {
            HStack(spacing: 8) {
                if showsIcons {
                    Label {
                        Text(title ?? l10n.s.mixerInputTitle)
                            .font(.system(size: 11.5, weight: .medium))
                    } icon: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .frame(width: 16)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text(title ?? l10n.s.mixerInputTitle)
                        .font(.body)
                }

                Spacer(minLength: 6)

                if inputManager.inputDevices.isEmpty {
                    Text(l10n.s.mixerInputNoDevices)
                        .font(showsIcons ? .system(size: 11.5) : .body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Picker(l10n.s.mixerInputTooltip, selection: inputSelectionBinding) {
                        if !audioPriority.inputPriorityEnabled {
                            Text(l10n.s.mixerOutputDefault)
                                .tag(MixerRoutingSupport.systemDefaultSelectionID)
                        }
                        ForEach(inputManager.inputDevices) { device in
                            Text(inputDeviceTitle(device))
                                .tag(device.uid)
                        }
                        if !audioPriority.inputPriorityEnabled,
                           let selected = inputManager.preferredInputDeviceUID,
                           inputManager.preferredUnavailable {
                            Text(l10n.s.mixerInputUnavailable)
                                .tag(selected)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(showsIcons ? .small : .regular)
                    .frame(width: 164)
                    .disabled(inputManager.inputDevices.isEmpty)
                    .help(l10n.s.mixerInputTooltip)
                }
            }

            let hasVolume = inputManager.inputVolume != nil
            HStack(spacing: 8) {
                if showsIcons {
                    Button {
                        toggleInputMute()
                    } label: {
                        AnimatedMicMuteSymbol(muted: isInputMuted, fontSize: 10.5)
                            .equatable()
                            .foregroundStyle(isInputMuted ? Color.red : Color.secondary)
                            .animation(.easeInOut(duration: 0.22), value: isInputMuted)
                            .frame(width: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isInputMuted ? l10n.s.actionUnmute : l10n.s.actionMute)
                }

                Text(levelTitle ?? l10n.s.mixerInputLevelLabel)
                    .font(showsIcons ? .system(size: 11.5, weight: .medium) : .body)
                    .foregroundStyle(showsIcons ? .secondary : .primary)

                Spacer(minLength: 12)

                if !showsIcons {
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
                }

                DeviceControlsSlider(
                    title: levelTitle ?? l10n.s.mixerInputLevelLabel,
                    value: inputVolumeBinding,
                    range: 0...1,
                    step: 0,
                    readout: "\(Int((displayedInputVolume * 100).rounded()))%",
                    onEditingChanged: { editing in
                        if !editing {
                            if let finalVol = draggingInputVolume, finalVol > 0.001 {
                                persistLastUnmutedInputVolume(finalVol)
                                if !micMute.isMuted {
                                    inputManager.setInputVolume(finalVol)
                                }
                            }
                            draggingInputVolume = nil
                            unmutingFromDrag = false
                        }
                    }
                )
                .frame(width: sliderWidth)
                .disabled(!hasVolume)
            }
            .padding(.vertical, showsIcons ? 4 : 0)

            if let lastError = inputManager.lastError {
                inputMessage(String(format: l10n.s.mixerInputErrorFormat, lastError),
                             systemImage: "exclamationmark.triangle")
            }
        }
        .onAppear { AudioInputDeviceManager.shared.syncWithPreferences() }
        .onChange(of: micMute.isMuted) { _, muted in
            if !muted {
                unmutingFromDrag = false
                if let pending = draggingInputVolume, pending > 0.001 {
                    inputManager.setInputVolume(pending)
                }
            }
        }
    }

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

    private func persistLastUnmutedInputVolume(_ value: Double) {
        lastUnmutedInputVolume = value
        UserDefaults.standard.set(value, forKey: "audioInputLastUnmutedVolume")
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
                persistLastUnmutedInputVolume(cur)
            }
            micMute.setMuted(true)
        }
    }

    private var inputSelectionBinding: Binding<String> {
        Binding(
            get: {
                if audioPriority.inputPriorityEnabled {
                    return inputManager.currentInputDeviceUID
                        ?? inputManager.inputDevices.first?.uid
                        ?? ""
                }
                return inputManager.preferredInputDeviceUID
                    ?? MixerRoutingSupport.systemDefaultSelectionID
            },
            set: { selection in
                if audioPriority.inputPriorityEnabled {
                    inputManager.setCurrentInputDeviceUID(selection)
                } else {
                    inputManager.setPreferredInputDeviceUID(
                        selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection)
                }
            }
        )
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

    private func inputDeviceTitle(_ device: MixerInputDevice) -> String {
        device.name
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
