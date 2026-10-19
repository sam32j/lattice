// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

// MARK: - Shared permission row

enum PermissionKind {
    case accessibility
    case screenRecording
    case microphone
}

/// Status + actions for one TCC permission; shared across Settings pages.
struct PermissionRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var pollingDemandID = UUID()
    let kind: PermissionKind

    private var granted: Bool {
        switch kind {
        case .accessibility: return permissions.accessibility
        case .screenRecording: return permissions.screenRecording
        case .microphone: return permissions.microphone == .granted
        }
    }

    private var monitorsActivePermission: Bool {
        switch kind {
        case .accessibility, .screenRecording: return true
        case .microphone: return false
        }
    }

    private var name: String {
        switch kind {
        case .accessibility: return l10n.s.permissionAccessibility
        case .screenRecording: return l10n.s.permissionScreenRecording
        case .microphone:
            return FeatureStrings.recorder(l10n.language).microphonePermissionName
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                Text(name)
                Spacer()
                Text(granted ? l10n.s.permissionGranted : l10n.s.permissionMissing)
                    .font(.caption)
                    .foregroundStyle(granted ? .green : .orange)
            }
            if !granted {
                HStack(spacing: 8) {
                    Button(l10n.s.permissionRequest) {
                        switch kind {
                        case .accessibility:
                            permissions.requestAccessibility()
                        case .screenRecording:
                            permissions.requestScreenRecording()
                        case .microphone:
                            permissions.requestMicrophone()
                        }
                    }
                    Button(l10n.s.permissionOpenSettings) {
                        switch kind {
                        case .accessibility:
                            permissions.openAccessibilitySettings()
                        case .screenRecording:
                            permissions.openScreenRecordingSettings()
                        case .microphone:
                            permissions.openMicrophoneSettings()
                        }
                    }
                }
                .controlSize(.small)
            }
        }
        .onAppear {
            if monitorsActivePermission {
                permissions.setActivePermissionSurface(pollingDemandID, visible: true)
            }
        }
        .onDisappear {
            permissions.setActivePermissionSurface(pollingDemandID, visible: false)
        }
    }
}
