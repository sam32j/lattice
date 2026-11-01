// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

// MARK: - Shared permission portal

struct PermissionsPortalSections: View {
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var bluetooth = BluetoothPermissionAccess.shared
    let hub: FeatureHubStrings
    let visiblePermissions: [AppPermission]
    @State private var automation: [Permissions.AutomationTarget: Permissions.AutomationStatus] = [:]
    @State private var pollingDemandID = UUID()
    @State private var automationRefreshID: UUID?
    @State private var audioStatus: SystemAudioAuthorizationStatus = .unavailable
    @State private var audioCheck: FeatureWorkCancellation?
    @State private var audioRefreshID: UUID?
    @State private var isVisible = false

    init(hub: FeatureHubStrings,
         visiblePermissions: [AppPermission] = AppPermission.allCases) {
        self.hub = hub
        self.visiblePermissions = visiblePermissions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visiblePermissions, id: \.self) { permission in
                PermissionPortalRow(permission: permission,
                                    hub: hub,
                                    status: status(for: permission),
                                    requestAvailable: requestAvailable(for: permission),
                                    requestInFlight: permission == .calendar && permissions.requestingCalendar,
                                    onRequestFinished: refreshRequestStatuses)
                if permission != visiblePermissions.last {
                    DataSettingsDivider()
                }
            }
        }
        .onAppear {
            isVisible = true
            // Statuses that only refresh at launch/activation get a fresh
            // read the moment the portal shows; automation is checked off the
            // main thread because the AE round trip can block briefly.
            permissions.refresh()
            bluetooth.refresh()
            if visiblePermissions.contains(.accessibility)
                || visiblePermissions.contains(.screenRecording) {
                permissions.setActivePermissionSurface(pollingDemandID, visible: true)
            }
            refreshRequestStatuses()
        }
        .onDisappear {
            isVisible = false
            automationRefreshID = nil
            audioRefreshID = nil
            audioCheck?.cancel()
            audioCheck = nil
            permissions.setActivePermissionSurface(pollingDemandID, visible: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            bluetooth.refresh()
            refreshRequestStatuses()
        }
    }

    private func requestAvailable(for permission: AppPermission) -> Bool {
        switch permission {
        case .accessibility, .screenRecording: return true
        case .audioCapture:
            return audioStatus == .notDetermined
        case .camera: return permissions.camera == .undetermined
        case .bluetooth: return BluetoothAuthorizationPolicy.canRequest(bluetooth.authorization)
        case .notifications: return permissions.notifications == .undetermined
        case .automationFinder: return automation[.finder] == .undetermined
        case .automationTerminal: return automation[.terminal] == .undetermined
        case .automationSystemEvents: return automation[.systemEvents] == .undetermined
        case .microphone: return permissions.microphone == .undetermined
        case .calendar: return permissions.calendarAccess == .notDetermined || permissions.calendarAccess == .writeOnly
        default: return false
        }
    }

    private func refreshRequestStatuses() {
        refreshAutomation()
        guard isVisible, visiblePermissions.contains(.audioCapture) else { return }
        audioCheck?.cancel()
        let id = UUID()
        audioRefreshID = id
        audioCheck = SystemAudioRecordingAccess.check { status in
            guard isVisible, audioRefreshID == id else { return }
            audioRefreshID = nil
            audioCheck = nil
            audioStatus = status
        }
    }

    private func refreshAutomation() {
        guard isVisible else { return }
        let request = UUID()
        automationRefreshID = request
        let targets = Permissions.AutomationTarget.allCases.filter { target in
            switch target {
            case .finder: return visiblePermissions.contains(.automationFinder)
            case .terminal: return visiblePermissions.contains(.automationTerminal)
            case .systemEvents: return visiblePermissions.contains(.automationSystemEvents)
            }
        }
        guard !targets.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let readings = Dictionary(uniqueKeysWithValues: targets.map { ($0, Permissions.automationStatus(for: $0)) })
            DispatchQueue.main.async {
                guard self.automationRefreshID == request else { return }
                self.automation = readings
            }
        }
    }

    private func status(for permission: AppPermission) -> PermissionPortalRow.Status {
        switch permission {
        case .accessibility: return permissions.accessibility ? .granted : .missing
        case .screenRecording: return permissions.screenRecording ? .granted : .missing
        case .fullDiskAccess: return permissions.fullDiskAccess ? .granted : .missing
        case .filesAndFolders: return .unknown
        case .notifications:
            switch permissions.notifications {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        case .automationFinder: return automationStatus(.finder)
        case .automationTerminal: return automationStatus(.terminal)
        case .automationSystemEvents: return automationStatus(.systemEvents)
        case .automationPlayback: return .unknown
        case .audioCapture:
            switch audioStatus {
            case .granted: return .granted
            case .denied, .notDetermined: return .missing
            case .unavailable: return .unknown
            }
        case .microphone:
            switch permissions.microphone {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        case .calendar:
            return permissions.calendarAccess == .fullAccess ? .granted : .missing
        case .camera:
            switch permissions.camera {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        case .bluetooth:
            switch BluetoothAuthorizationPolicy.status(bluetooth.authorization) {
            case .granted: return .granted
            case .missing: return .missing
            case .unknown: return .unknown
            }
        case .appManagement:
            // macOS has no public preflight API for this permission. The
            // system records the app only after its first protected write.
            return .unknown
        }
    }

    private func automationStatus(_ target: Permissions.AutomationTarget) -> PermissionPortalRow.Status {
        switch automation[target] {
        case .granted: return .granted
        case .denied, .undetermined: return .missing
        case .notDeterminable, .none: return .unknown
        }
    }
}
