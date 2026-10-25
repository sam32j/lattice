// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct PermissionPortalRow: View {
    enum Status { case granted, missing, unknown }

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsDetails = false
    let permission: AppPermission
    let hub: FeatureHubStrings
    let status: Status

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // The tile wears the status color, so a glance down the list
            // shows what is granted before any word is read.
            Image(systemName: permission.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)
                .background(statusColor.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(permission.name(hub))
                        .fontWeight(.medium)
                    statusChip
                    Spacer(minLength: 8)
                    Button {
                        showsDetails = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(detailsLabel)
                    .accessibilityIdentifier("permission.details.\(permission.rawValue)")
                    .help(detailsLabel)
                }
                HStack(spacing: 8) {
                    if status != .granted, hasRequestFlow {
                        Button(hub.requestButton) { request() }
                    }
                    Button(hub.openSystemSettings) { openSystemSettings() }
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showsDetails) {
            PermissionDetailsSheet(title: permission.name(hub),
                                   explanation: permission.explainer(hub),
                                   features: activeFeatures.map { ($0.hubTitle(l10n.s, hub: hub), $0.symbolName) },
                                   isUnused: status == .granted && activeFeatures.isEmpty,
                                   hub: hub)
        }
    }

    private var activeFeatures: [AppFeature] {
        AppFeature.activeFeatures(using: permission).filter {
            permission != .notifications || $0 != .monitorPower || PowerSampler.hasInternalBattery
        }
    }

    private var detailsLabel: String {
        "\(permission.name(hub)): \(DataPermissionsStrings.localized(l10n.language).details)"
    }

    private var statusChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(chipText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: return PanelMetricColor.green(for: colorScheme)
        case .missing: return PanelMetricColor.orange(for: colorScheme)
        case .unknown: return .secondary
        }
    }

    private var chipText: String {
        switch status {
        case .granted: return hub.statusGranted
        case .missing: return hub.statusMissing
        case .unknown: return hub.statusUnknown
        }
    }

    private var hasRequestFlow: Bool {
        switch permission {
        case .accessibility, .screenRecording, .fullDiskAccess: return true
        case .notifications: return Permissions.shared.notifications == .undetermined
        case .calendar: return Permissions.shared.calendarAccess == .notDetermined
            || Permissions.shared.calendarAccess == .writeOnly
        case .camera: return Permissions.shared.camera == .undetermined
        case .microphone: return Permissions.shared.microphone == .undetermined
        case .bluetooth: return BluetoothAuthorizationPolicy.canRequest(BluetoothPermissionAccess.shared.authorization)
        case .filesAndFolders, .automationFinder, .automationTerminal, .automationPlayback, .audioCapture,
             .appManagement: return false
        }
    }

    private func request() {
        switch permission {
        case .accessibility: Permissions.shared.requestAccessibility()
        case .screenRecording: Permissions.shared.requestScreenRecording()
        case .fullDiskAccess: Permissions.shared.requestFullDiskAccess()
        case .notifications:
            Notifier.requestPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Permissions.shared.refresh()
            }
        case .calendar: Permissions.shared.requestCalendar()
        case .camera: Permissions.shared.requestCamera()
        case .microphone: Permissions.shared.requestMicrophone()
        case .bluetooth: BluetoothPermissionAccess.shared.request()
        case .filesAndFolders, .automationFinder, .automationTerminal, .automationPlayback, .audioCapture,
             .appManagement:
            break
        }
    }

    private func openSystemSettings() {
        switch permission {
        case .accessibility: Permissions.shared.openAccessibilitySettings()
        case .screenRecording: Permissions.shared.openScreenRecordingSettings()
        case .fullDiskAccess: Permissions.shared.openFullDiskAccessSettings()
        case .filesAndFolders: Permissions.shared.openFilesAndFoldersSettings()
        case .notifications: Permissions.shared.openNotificationSettings()
        case .automationFinder, .automationTerminal, .automationPlayback: Permissions.shared.openAutomationSettings()
        case .audioCapture: Permissions.shared.openAudioCaptureSettings()
        case .microphone: Permissions.shared.openMicrophoneSettings()
        case .calendar: Permissions.shared.openCalendarSettings()
        case .camera: Permissions.shared.openCameraSettings()
        case .appManagement: Permissions.shared.openAppManagementSettings()
        case .bluetooth: BluetoothPermissionAccess.shared.openSettings()
        }
    }
}
