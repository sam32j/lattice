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
    @State private var draggingInputVolume: Double? = nil
    @State private var unmutingFromDrag = false
    @State private var pendingUnmuteLevel: PendingInputUnmuteLevel?
    /// The audible level a drag started from, remembered for Unmute when the
    /// drag ends at zero.
    @State private var levelBeforeEdit: Double?

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
                    onEditingChanged: { editing in
                        if !editing {
                            finishInputEdit()
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
            guard !muted else {
                pendingUnmuteLevel = nil
                return
            }
            unmutingFromDrag = false
            if let dragging = draggingInputVolume, dragging > 0.001 {
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

    private func toggleInputMute() {
        let currentlyMuted = micMute.isMuted || (inputManager.inputVolume != nil && (inputManager.inputVolume ?? 0) <= 0.001)
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
            if let cur = inputManager.inputVolume, cur > 0.001 {
                inputManager.rememberUnmutedInputVolume(cur)
            }
            micMute.setMuted(true)
        }
    }

    /// Ends a slider edit. A level chosen while the unmute it started is
    /// still in flight waits for it; a drag to zero remembers where it began.
    private func finishInputEdit() {
        if let finalVol = draggingInputVolume {
            if finalVol > 0.001 {
                inputManager.rememberUnmutedInputVolume(finalVol)
                if micMute.isMuted {
                    pendingUnmuteLevel = PendingInputUnmuteLevel(deviceUID: inputManager.effectiveInputDeviceUID,
                                                                 value: finalVol)
                } else {
                    inputManager.setInputVolume(finalVol)
                }
            } else if let before = levelBeforeEdit {
                inputManager.rememberUnmutedInputVolume(before)
            }
        }
        draggingInputVolume = nil
        unmutingFromDrag = false
        levelBeforeEdit = nil
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
                if draggingInputVolume == nil, !micMute.isMuted,
                   let current = inputManager.inputVolume, current > 0.001 {
                    levelBeforeEdit = current
                }
                draggingInputVolume = newValue
                if micMute.isMuted, newValue > 0.001 {
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
