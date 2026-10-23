// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct PermissionGatedSettingsRow: View {
    let title: String
    var caption: String?
    @Binding var isOn: Bool
    var requiring: [SettingsPermission] = [.accessibility]

    var body: some View {
        SettingsControlRow(title: title, caption: caption) {
            PermissionGatedToggle(title, isOn: $isOn, requiring: requiring)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

extension AppFeature {
    /// Essential permissions for enabling the feature, not optional capabilities
    /// such as recording microphone audio or automating Finder commands.
    var activationPermissions: [SettingsPermission] {
        switch self {
        case .switcher, .dockPreview: return [.accessibility, .screenRecording]
        case .screenshot, .screenRecorder, .notchWatch: return [.screenRecording]
        case .cameraPreview: return [.camera]
        case .notchCalendar: return [.calendar]
        default: return permissions.contains(.accessibility) ? [.accessibility] : []
        }
    }
}
