// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Per-app volume sliders, the mixer macOS never shipped. Shows every app
/// holding an audio connection (a green dot marks the ones playing right now).
/// 100% is untouched passthrough; below it attenuates and above it (up to 200%)
/// boosts, with the slider and percentage turning amber in the boost range.
struct MixerSection: View {
    @Environment(\.notchPresentation) private var inNotch
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var windowsGlass = false
    @AppStorage(DefaultsKey.notchLiquidGlassEnabled) private var islandGlass = false
    @AppStorage(DefaultsKey.mixerAppArrangement)
    private var arrangementValue = ""
    @AppStorage(DefaultsKey.mixerHideInactiveApps)
    private var hideInactiveApps = false
    @State private var optionsExpanded = false
    @State private var normalSliderTint = Color(nsColor: .controlAccentColor)
    @State private var accentRevision = 0
    @State private var lastResolvedAccent: NSColor?
    @State private var editingVolumeID: String?
    @State private var draggingAppID: String?
    @State private var dropTarget: MixerAppDropTarget?
    @AppStorage(DefaultsKey.volumeMixerEnabled) private var volumeMixerEnabled = true
    var collapsible = true
    var settingsMode = false

    private var glassEnabled: Bool {
        LiquidGlassSupport.isEnabled(inNotch: inNotch, windows: windowsGlass, island: islandGlass)
    }

    var body: some View {
        Group {
            if settingsMode {
                SettingsCard(title: l10n.s.volumeMixerEnable, headerAccessory: {
                    Toggle(l10n.s.volumeMixerEnable, isOn: $volumeMixerEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .help(l10n.s.volumeMixerEnable)
                        .accessibilityLabel(l10n.s.volumeMixerEnable)
                        .onChange(of: volumeMixerEnabled) { _, enabled in
                            FeatureRuntime.shared.setAvailable([.mixer], enabled)
                            AppVolumeMixer.shared.syncWithPreferences()
                            PreciseVolumeRollerService.shared.syncWithPreferences()
                        }
                }) {
                    mixerControls
                        .disabled(!volumeMixerEnabled)
                        .opacity(volumeMixerEnabled ? 1 : 0.55)
                }
            } else {
                PanelSection(.mixer, title: l10n.s.mixerSection, collapsible: collapsible) {
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
        .onAppear { mixer.refreshApps() }
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
                optionsExpanded.toggle()
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

            if let volume = mixer.systemOutputVolume {
                HStack(spacing: 8) {
                    Image(systemName: mixer.systemOutputMuted == true || volume <= 0.001
                          ? "speaker.slash.fill"
                          : "speaker.wave.2.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(l10n.s.mixerOutputLevelLabel)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    MixerVolumeSlider(value: systemOutputVolumeBinding,
                                      normalTint: normalSliderTint,
                                      boostTint: normalSliderTint,
                                      isBoosting: false,
                                      accentRevision: accentRevision,
                                      glassEnabled: glassEnabled,
                                      maximum: 1,
                                      accessibilityLabel: l10n.s.mixerOutputLevelLabel)

                    EditableVolumePercent(currentPercent: Int((volume * 100).rounded()),
                                          maximumPercent: 100,
                                          width: 36,
                                          editorID: "system-output",
                                          editingID: $editingVolumeID,
                                          accessibilityLabel: l10n.s.mixerOutputLevelLabel) {
                        Text("\(Int((volume * 100).rounded()))%")
                            .font(.system(size: 10.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } onCommit: {
                        setSystemOutputVolume($0)
                    }
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

    private func setSystemOutputVolume(_ value: Double) {
        if inNotch {
            // The slider shows the level; the island's header need not repeat it.
            NotchService.shared.noteOwnVolumeAdjustment()
            mixer.requestOutputAdjustment(volume: value)
        } else { mixer.setCurrentOutputVolume(value) }
    }

    private var systemOutputVolumeBinding: Binding<Double> {
        Binding(
            get: { mixer.systemOutputVolume ?? 0 },
            set: { setSystemOutputVolume($0) }
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

/// The options under the routing, shared with the island's mixer page so
/// both surfaces offer the same switches: idle rows, the headphone guard, the
/// precise roller, the output switcher and the hidden apps.
struct MixerOptionsControls: View {
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
                   isOn: $lowerOnHeadphonesDisconnect)
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
            Toggle(l10n.s.preciseVolumeRollerEnable, isOn: $preciseVolumeRollerEnabled)
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

                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(arrangementStrings.pin)
                    }
                    Spacer(minLength: 4)

                    if app.persistenceID != nil {
                        Menu { arrangementActions } label: {
                            Image(systemName: "ellipsis")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help(isPinned ? arrangementStrings.unpin : arrangementStrings.pin)
                        .accessibilityLabel("\(isPinned ? arrangementStrings.unpin : arrangementStrings.pin): \(app.name)")
                    }
                    if !app.isBypassed {
                        outputPicker
                    }
                }

                if app.isBypassed {
                    // Zoom and pro audio apps are listed but never tapped
                    // (issue #177): the row explains itself instead of the
                    // app silently missing from the mixer.
                    Text(l10n.s.mixerBypassedCaption)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 8) {
                        MixerVolumeSlider(value: volumeBinding,
                                          normalTint: normalTint,
                                          boostTint: boostColor,
                                          isBoosting: isBoosting,
                                          accentRevision: accentRevision,
                                          glassEnabled: glassEnabled,
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
            ForEach(mixer.outputDevices) { device in
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
            if mixer.outputDevices.contains(where: { MixerRoutingSupport.isAirPlaySentinel($0.uid) }) {
                Divider()
                Text(l10n.s.mixerAirPlayChooseSpeaker)
                    .tag(MixerRoutingSupport.airPlaySpeakerChoiceID)
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

/// The percentage keeps its compact read-only appearance until clicked, then
/// becomes a selected text field so the next keystroke replaces the old value.
