// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct PermissionPortalRow: View {
    typealias Status = PermissionRowStatus
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var scheme
    @State private var showsDetails = false
    @State private var requestingMicrophone = false
    @State private var attemptedManualRequest = false
    let permission: AppPermission
    let hub: FeatureHubStrings
    let status: Status
    var requestAvailable = false
    var requestInFlight = false

    private var title: String {
        switch permission {
        case .accessibility: return copy(.deviceAccess)
        case .audioCapture: return copy(.systemAudio)
        default: return permission.name(hub)
        }
    }
    private func copy(_ key: DataPermissionsPageCopy.Key) -> String {
        DataPermissionsPageCopy.text(key, l10n.language)
    }
    private var symbol: String {
        switch permission {
        case .screenRecording: return "viewfinder"
        case .fullDiskAccess: return "externaldrive"
        case .filesAndFolders: return "folder"
        case .notifications: return "bell"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        default: return permission.symbolName
        }
    }
    private var rowAction: PermissionRowAction {
        PermissionRowActionPolicy.action(for: permission, status: status,
            requestAvailable: requestAvailable && !attemptedManualRequest)
    }
    private var tone: DataSettingsTone {
        switch status {
        case .granted: return .granted
        case .missing: return .missing
        case .unknown: return .neutral
        }
    }
    private var actionTone: DataSettingsActionTone {
        switch rowAction {
        case .request: return .primary
        case .settingsRequired: return .outline
        case .settings: return .quiet
        }
    }
    private var statusText: String {
        switch status {
        case .granted: return hub.statusGranted
        case .missing: return hub.statusMissing
        case .unknown: return hub.statusUnknown
        }
    }

    var body: some View {
        DataPermissionsRow(symbol: symbol, title: title, status: statusText,
            tone: tone, information: AnyView(detailsButton),
            actionTitle: rowAction == .request ? hub.requestButton : copy(.settings),
            actionTone: actionTone,
            actionAccessibleName: String(format: copy(rowAction == .request ? .requestAccess : .openSettings), title),
            actionEnabled: !requestInFlight && !requestingMicrophone) {
                if rowAction == .request { request() } else { openSystemSettings() }
            }
            .accessibilityIdentifier("permission.row.\(permission.rawValue)")
    }

    private var detailsButton: some View {
        Button { showsDetails = true } label: {
            Image(systemName: "info.circle").font(.system(size: 14))
                .foregroundStyle(DataPermissionsPalette(scheme).info)
                .frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(title): \(DataPermissionsStrings.localized(l10n.language).details)")
        .accessibilityIdentifier("permission.details.\(permission.rawValue)")
        .popover(isPresented: $showsDetails, arrowEdge: .leading) {
            PermissionDetailsSheet(title: title, explanation: permission.explainer(hub),
                features: activeFeatures.map { ($0.hubTitle(l10n.s, hub: hub), $0.symbolName) },
                isUnused: status == .granted && activeFeatures.isEmpty, hub: hub,
                onOpenSystemSettings: openSystemSettings)
        }
    }

    private var activeFeatures: [AppFeature] {
        AppFeature.activeFeatures(using: permission).filter {
            permission != .notifications || $0 != .monitorPower || PowerSampler.hasInternalBattery
        }
    }

    private func request() {
        switch permission {
        case .fullDiskAccess:
            attemptedManualRequest = true
            Permissions.shared.requestFullDiskAccess()
        case .calendar: Permissions.shared.requestCalendar()
        case .microphone:
            requestingMicrophone = true
            Permissions.shared.requestMicrophone { _ in requestingMicrophone = false }
        default: openSystemSettings()
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
