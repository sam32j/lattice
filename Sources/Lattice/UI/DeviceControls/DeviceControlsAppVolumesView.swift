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

    /// Rows whose slider is being dragged. They stay listed until the drag
    /// ends, even if their app stops playing meanwhile, so the drag is not cut
    /// short by its row disappearing.
    @State private var trackingAppIDs: Set<String> = []

    private func staysListed(_ app: MixerApp) -> Bool {
        isActiveApp(app) || arrangement.isPinned(app.persistenceID) || trackingAppIDs.contains(app.id)
    }

    private var activeApps: [MixerApp] {
        orderedApps.filter { staysListed($0) }
    }

    private var inactiveApps: [MixerApp] {
        orderedApps.filter { !staysListed($0) }
    }

    private var activeCount: Int {
        orderedApps.filter { isActiveApp($0) }.count
    }

    private var totalCount: Int {
        orderedApps.count
    }

    /// The order rows were first shown in. An app starting or stopping
    /// playback, or the mixer listing apps afresh, never moves a row under
    /// the pointer or a slider being dragged; new apps join at the end.
    @State private var shownOrder: [String] = []

    private var displayedApps: [MixerApp] {
        let listed = navigation.showInactiveApps ? activeApps + inactiveApps : activeApps
        let rank = Dictionary(shownOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return listed.enumerated().sorted { lhs, rhs in
            let left = rank[lhs.element.id] ?? Int.max, right = rank[rhs.element.id] ?? Int.max
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
    }

    private func rememberOrder(_ apps: [MixerApp]) {
        let known = Set(shownOrder)
        let added = apps.map(\.id).filter { !known.contains($0) }
        if !added.isEmpty { shownOrder += added }
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
            if mixer.apps.isEmpty {
                mixer.refreshApps()
            }
            rememberOrder(navigation.showInactiveApps ? activeApps + inactiveApps : activeApps)
        }
        .onChange(of: displayedApps.map(\.id)) { _, _ in
            rememberOrder(navigation.showInactiveApps ? activeApps + inactiveApps : activeApps)
        }
    }

    private var availableOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter { !MixerRoutingSupport.isAirPlaySentinel($0.uid) }
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
                    availableOutputDevices: availableOutputDevices,
                    onTogglePin: {
                        updateArrangement { $0.togglePin(app.persistenceID ?? "") }
                    },
                    onSliderTrackingChanged: { tracking in
                        if tracking {
                            trackingAppIDs.insert(app.id)
                        } else {
                            trackingAppIDs.remove(app.id)
                        }
                    }
                )
                .frame(
                    height: DeviceControlsAppVolumesLayout.rowHeight,
                    alignment: .top
                )
            }
        }
        .panelCard(interactive: false, padded: false)
    }
}

private struct DeviceControlsAppRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    let app: MixerApp
    let active: Bool
    let isPinned: Bool
    let availableOutputDevices: [MixerOutputDevice]
    let onTogglePin: () -> Void
    var onSliderTrackingChanged: (Bool) -> Void = { _ in }

    /// Only the pointer on the icon previews Pin; anywhere else on the row
    /// the playing dot stays visible.
    @State private var isIconHovered = false
    @State private var isSliderEditing = false
    @State private var liveVolume: Double?

    private var effectiveVolume: Double { liveVolume ?? app.volume }

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
                    liveVolume = nil
                    if (effectiveVolume * 100).rounded() == 100 {
                        AppVolumeMixer.shared.toggleMute(app)
                    } else {
                        AppVolumeMixer.shared.setVolume(1.0, for: app)
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    }
                } label: {
                    Image(systemName: speakerIcon(for: effectiveVolume))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(speakerColor(for: effectiveVolume))
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
                            get: { liveVolume ?? app.volume },
                            set: { nextVol in
                                if isSliderEditing {
                                    liveVolume = nextVol
                                    AppVolumeMixer.shared.setInteractiveVolume(nextVol, for: app, isEditing: true)
                                } else {
                                    liveVolume = nil
                                    AppVolumeMixer.shared.setVolume(nextVol, for: app)
                                }
                            }
                        ),
                        onEditingChanged: { editing in
                            isSliderEditing = editing
                            onSliderTrackingChanged(editing)
                            if !editing, let finalVol = liveVolume {
                                liveVolume = nil
                                AppVolumeMixer.shared.setVolume(finalVol, for: app)
                            }
                            if !editing { AppVolumeMixer.shared.endInteractiveVolume(for: app) }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .compositingGroup()
        .opacity(active ? 1.0 : 0.65)
        .contentShape(Rectangle())
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
            .onHover { isIconHovered = $0 }
            .help(pinActionTitle)
            .accessibilityLabel("\(pinActionTitle) \(app.name)")
        } else {
            iconContent
        }
    }

    private var pinActionTitle: String {
        isPinned ? FeatureStrings.mixer(l10n.language).unpin : FeatureStrings.mixer(l10n.language).pin
    }

    private var iconContent: some View {
        Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid, pointSize: Self.iconSize))
            .resizable()
            .frame(width: Self.iconSize, height: Self.iconSize)
            .overlay(alignment: .bottomTrailing) {
                if isPinned || (isIconHovered && app.persistenceID != nil) {
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
            .animation(.easeOut(duration: 0.15), value: isIconHovered)
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
               let route = AppVolumeMixer.shared.outputDevices.first(where: { $0.uid == selected }) {
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
                AppVolumeMixer.shared.setOutputDeviceUID(
                    selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection,
                    for: app
                )
            }
        )
    }
}
