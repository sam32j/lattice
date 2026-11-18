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
        DeviceControlsAppVolumesLayout.isActive(app, arrangement: arrangement)
    }

    private var orderedApps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID })
    }

    private var activeApps: [MixerApp] {
        orderedApps.filter { isActiveApp($0) || arrangement.isPinned($0.persistenceID) }
    }

    private var inactiveApps: [MixerApp] {
        orderedApps.filter { !isActiveApp($0) && !arrangement.isPinned($0.persistenceID) }
    }

    private var activeCount: Int {
        orderedApps.filter { isActiveApp($0) }.count
    }

    private var totalCount: Int {
        orderedApps.count
    }

    private var displayedApps: [MixerApp] {
        if navigation.showInactiveApps {
            return activeApps + inactiveApps
        } else {
            return activeApps
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
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .frame(height: DeviceControlsAppVolumesLayout.headerHeight)
    }

    // MARK: - Empty Active State

    private var emptyStateHeight: CGFloat {
        max(
            DeviceControlsAppVolumesLayout.emptyActiveHeight,
            navigation.measuredMainHeight
                - DeviceControlsAppVolumesLayout.headerHeight
                - DeviceControlsAppVolumesLayout.sectionSpacing
                - 10
        )
    }

    private var emptyActiveState: some View {
        Text("No app playing")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .offset(y: -(DeviceControlsAppVolumesLayout.headerHeight + DeviceControlsAppVolumesLayout.sectionSpacing) / 2)
            .frame(maxWidth: .infinity, minHeight: emptyStateHeight, alignment: .center)
    }

    // MARK: - Apps Grouped Container

    private var appsContainer: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayedApps.enumerated()), id: \.element.id) { index, app in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, 10)
                        .frame(height: DeviceControlsAppVolumesLayout.dividerHeight)
                }
                DeviceControlsAppRow(
                    app: app,
                    active: isActiveApp(app),
                    isPinned: arrangement.isPinned(app.persistenceID),
                    onTogglePin: {
                        updateArrangement { $0.togglePin(app.persistenceID ?? "") }
                    }
                )
                .frame(
                    height: DeviceControlsAppVolumesLayout.rowHeight,
                    alignment: .top
                )
            }
        }
        .panelCard(padded: false)
    }
}

private struct DeviceControlsAppRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    let app: MixerApp
    let active: Bool
    let isPinned: Bool
    let onTogglePin: () -> Void

    @State private var isHovered = false

    private static let iconSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1 — Identity and output routing
            HStack(spacing: 8) {
                appIconView

                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                if !app.isBypassed {
                    outputPicker(for: app)
                }
            }

            // Row 2 — Volume control
            HStack(spacing: 8) {
                // Speaker icon: doubles as reset button (aligned with app icon)
                Button {
                    if (app.volume * 100).rounded() == 100 {
                        mixer.toggleMute(app)
                    } else {
                        mixer.setVolume(1.0, for: app)
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    }
                } label: {
                    Image(systemName: speakerIcon(for: app.volume))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(speakerColor(for: app.volume))
                        .frame(width: 32, height: 24, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(app.isBypassed)
                .accessibilityLabel(speakerAccessibilityLabel(for: app))

                if app.isBypassed {
                    Text(l10n.s.mixerBypassedCaption)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    AppVolumeBoostSlider(
                        title: "\(app.name) volume",
                        value: Binding(
                            get: { app.volume },
                            set: { mixer.setVolume($0, for: app) }
                        )
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

    private func speakerIcon(for volume: Double) -> String {
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

    private func speakerColor(for volume: Double) -> Color {
        if volume <= 0.001 {
            return Color.secondary
        } else if volume > 1.0 {
            return Color.orange
        } else {
            return Color.secondary
        }
    }

    private func speakerAccessibilityLabel(for app: MixerApp) -> String {
        if (app.volume * 100).rounded() == 100 {
            return "Mute \(app.name)"
        } else {
            return "Reset \(app.name) volume to 100%"
        }
    }

    private var availableOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter { !MixerRoutingSupport.isAirPlaySentinel($0.uid) }
    }

    private func outputPicker(for app: MixerApp) -> some View {
        Picker("Output", selection: outputSelectionBinding(for: app)) {
            Text(l10n.s.mixerOutputDefault)
                .tag(MixerRoutingSupport.systemDefaultSelectionID)

            ForEach(availableOutputDevices) { device in
                Text(device.name)
                    .tag(device.uid)
            }

            // A saved AirPlay route is left out of the list above but still
            // needs its own row, or the picker has nothing to show it with.
            if let selected = app.selectedOutputDeviceUID, !app.outputDeviceUnavailable,
               !availableOutputDevices.contains(where: { $0.uid == selected }),
               let route = mixer.outputDevices.first(where: { $0.uid == selected }) {
                Text(route.name)
                    .tag(selected)
            }

            if let selected = app.selectedOutputDeviceUID,
               MixerRoutingSupport.needsUnavailableOutputRow(
                selectedUID: selected,
                isUnavailable: app.outputDeviceUnavailable,
                listedUIDs: availableOutputDevices.map(\.uid)
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
