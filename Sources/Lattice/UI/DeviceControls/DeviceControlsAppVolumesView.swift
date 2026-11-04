// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// App Volumes subpage providing individual application volume, mute, pinning,
/// and audio output destination routing in a clean, compact grouped layout.
struct DeviceControlsAppVolumesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var navigation = DeviceControlsNavigationState.shared
    @AppStorage(DefaultsKey.mixerAppArrangement) private var arrangementValue = ""

    private var arrangement: MixerAppArrangement {
        MixerAppArrangement(rawValue: arrangementValue)
    }

    private func updateArrangement(_ change: (inout MixerAppArrangement) -> Void) {
        var updated = arrangement
        change(&updated)
        arrangementValue = updated.rawValue
    }

    private func isActiveApp(_ app: MixerApp) -> Bool {
        MixerRoutingSupport.shouldShowApp(
            isPlaying: app.isPlaying,
            volume: app.volume,
            selectedOutputDeviceUID: app.selectedOutputDeviceUID,
            hideInactiveApps: true
        )
    }

    private var orderedApps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID })
    }

    private var activeCount: Int {
        orderedApps.filter { isActiveApp($0) }.count
    }

    private var totalCount: Int {
        orderedApps.count
    }

    private var displayedApps: [MixerApp] {
        if navigation.showInactiveApps {
            return orderedApps
        } else {
            return orderedApps.filter { isActiveApp($0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerAndFilterBar

            if !AppVolumeMixer.isSupported {
                Text(l10n.s.mixerUnavailable)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if orderedApps.isEmpty {
                Text(l10n.s.mixerEmpty)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if displayedApps.isEmpty {
                emptyActiveState
            } else {
                appsContainer
            }
        }
        .onAppear {
            mixer.refreshApps()
        }
    }

    // MARK: - Subpage Header & Filter

    private var headerAndFilterBar: some View {
        HStack {
            Text("\(activeCount) active · \(totalCount) total")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)

            Spacer()

            Button(navigation.showInactiveApps ? "Hide inactive apps" : "Show inactive apps") {
                navigation.showInactiveApps.toggle()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Empty Active State

    private var emptyActiveState: some View {
        VStack(spacing: 8) {
            Text("No active apps")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)

            Button("Show inactive apps") {
                navigation.showInactiveApps = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5))
            .foregroundStyle(Color.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 32)
    }

    // MARK: - Apps Grouped Container

    private var appsContainer: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayedApps.enumerated()), id: \.element.id) { index, app in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, 10)
                }
                appRow(app)
            }
        }
        .panelCard(padded: false)
    }

    private func appRow(_ app: MixerApp) -> some View {
        let active = isActiveApp(app)
        let isPinned = arrangement.isPinned(app.persistenceID)

        return VStack(alignment: .leading, spacing: 6) {
            // Row 1 — Identity and output routing
            HStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32))
                        .resizable()
                        .frame(width: 32, height: 32)

                    if app.isPlaying {
                        Circle()
                            .fill(PanelMetricColor.green(for: colorScheme))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.2))
                            .offset(x: -1, y: -1)
                    }
                }
                .frame(width: 32, height: 32)

                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if app.persistenceID != nil {
                    MixerPinButton(
                        isPinned: isPinned,
                        pinTitle: FeatureStrings.mixer(l10n.language).pin,
                        unpinTitle: FeatureStrings.mixer(l10n.language).unpin,
                        appName: app.name,
                        action: {
                            updateArrangement { $0.togglePin(app.persistenceID ?? "") }
                        }
                    )
                }

                Spacer(minLength: 8)

                if !app.isBypassed {
                    outputPicker(for: app)
                }
            }

            // Row 2 — Volume control
            HStack(spacing: 8) {
                // Mute button: aligned horizontally with the app icon (32 pt width)
                Button {
                    mixer.toggleMute(app)
                } label: {
                    Image(systemName: app.volume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(app.volume <= 0.001
                                         ? PanelMetricColor.red(for: colorScheme)
                                         : Color.secondary)
                        .frame(width: 32, height: 24, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(app.volume <= 0.001 ? "Unmute \(app.name)" : "Mute \(app.name)")

                if app.isBypassed {
                    Text(l10n.s.mixerBypassedCaption)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    DeviceControlsSlider(
                        title: "\(app.name) volume",
                        value: Binding(
                            get: { app.volume },
                            set: { mixer.setVolume($0, for: app) }
                        ),
                        range: 0...AppVolumeMixer.maxVolume,
                        readout: "\(Int((app.volume * 100).rounded()))%",
                        tintColor: (app.volume * 100).rounded() > 100
                            ? PanelMetricColor.orange(for: colorScheme)
                            : nil
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .opacity(active ? 1.0 : 0.65)
    }

    private func outputPicker(for app: MixerApp) -> some View {
        Picker("Output", selection: outputSelectionBinding(for: app)) {
            Text(l10n.s.mixerOutputDefault)
                .tag(MixerRoutingSupport.systemDefaultSelectionID)

            ForEach(mixer.outputDevices) { device in
                Text(device.name)
                    .tag(device.uid)
            }

            if let selected = app.selectedOutputDeviceUID,
               MixerRoutingSupport.needsUnavailableOutputRow(
                selectedUID: selected,
                isUnavailable: app.outputDeviceUnavailable,
                listedUIDs: mixer.outputDevices.map(\.uid)
               ) {
                Text(l10n.s.mixerOutputUnavailable)
                    .tag(selected)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: 130)
    }

    private func outputSelectionBinding(for app: MixerApp) -> Binding<String> {
        Binding(
            get: { app.selectedOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                mixer.setOutputDeviceUID(
                    selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection,
                    for: app
                )
            }
        )
    }
}
