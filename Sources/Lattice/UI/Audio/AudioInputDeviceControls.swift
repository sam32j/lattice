import AppKit
import SwiftUI

/// Shared microphone controls used by Audio Input and the live menu panel.
struct AudioInputDeviceControls: View {
    var title: String? = nil
    var sliderWidth: CGFloat = 140
    var showsUnavailableLabel = false
    @Environment(\.notchPresentation) private var inNotch
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared
    @ObservedObject private var audioPriority = AudioPriorityService.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @State private var normalSliderTint = Color(nsColor: .controlAccentColor)
    @State private var accentRevision = 0
    @State private var lastResolvedAccent: NSColor?
    @State private var editingVolumeID: String?

    private var glassEnabled: Bool {
        LiquidGlassSupport.isSupported
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label {
                    Text(title ?? l10n.s.mixerInputTitle)
                        .font(.system(size: 11.5, weight: .medium))
                } icon: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .frame(width: 16)
                }
                .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                Picker(l10n.s.mixerInputTooltip, selection: inputSelectionBinding) {
                    Text(l10n.s.mixerOutputDefault)
                        .tag(MixerRoutingSupport.systemDefaultSelectionID)
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
                .controlSize(.small)
                .frame(width: 164)
                .disabled(inputManager.inputDevices.isEmpty)
                .help(l10n.s.mixerInputTooltip)
            }

            let hasVolume = inputManager.inputVolume != nil
            let volume = inputManager.inputVolume ?? 0
            HStack(spacing: 8) {
                Image(systemName: !hasVolume || volume <= 0.001 ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(l10n.s.mixerInputLevelLabel)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                SettingsValueSlider(title: l10n.s.mixerInputLevelLabel,
                                    value: inputVolumeBinding, range: 0...1, step: 0.01,
                                    readout: "\(Int((volume * 100).rounded()))%",
                                    usesSystemAppearance: true)
                    .frame(width: sliderWidth)
                    .disabled(!hasVolume)
                    .help(hasVolume ? "" : l10n.s.sliderUnavailable)
                if !hasVolume && showsUnavailableLabel {
                    Text(l10n.s.sliderUnavailable)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .disabled(micMute.isMuted)

            if inputManager.inputDevices.isEmpty {
                inputMessage(l10n.s.mixerInputNoDevices, systemImage: "mic.slash")
            } else if !audioPriority.inputPriorityEnabled, inputManager.preferredUnavailable {
                inputMessage(l10n.s.mixerInputFallback, systemImage: "mic.badge.xmark")
            } else if let lastError = inputManager.lastError {
                inputMessage(String(format: l10n.s.mixerInputErrorFormat, lastError),
                             systemImage: "exclamationmark.triangle")
            }
        }
        .onReceive(NSApplication.shared.publisher(for: \.effectiveAppearance, options: [.new])) { _ in refreshSliderTint() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NSSystemColorsDidChangeNotification"))) { _ in refreshSliderTint() }
    }

    private var inputSelectionBinding: Binding<String> {
        Binding(
            get: {
                return MixerRoutingSupport.selectedInputDeviceUID(
                    preferredUID: inputManager.preferredInputDeviceUID,
                    currentUID: inputManager.currentInputDeviceUID,
                    priorityIsActive: audioPriority.inputPriorityEnabled)
                    ?? MixerRoutingSupport.systemDefaultSelectionID
            },
            set: { selection in
                if audioPriority.inputPriorityEnabled {
                    guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
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
            get: { inputManager.inputVolume ?? 0 },
            set: { inputManager.setInputVolume($0) }
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
}
