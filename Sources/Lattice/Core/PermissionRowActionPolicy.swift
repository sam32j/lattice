// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum PermissionRowStatus { case granted, missing, unknown }
enum PermissionRowAction { case request, settings, settingsRequired }

enum PermissionPortalRequest: Equatable {
    case permission(SettingsPermission)
    case systemAudio, notifications, finderAutomation, terminalAutomation, systemEventsAutomation
}

enum PermissionRowActionPolicy {
    static func request(for permission: AppPermission) -> PermissionPortalRequest? {
        switch permission {
        case .accessibility: return .permission(.accessibility)
        case .screenRecording: return .permission(.screenRecording)
        case .microphone: return .permission(.microphone)
        case .camera: return .permission(.camera)
        case .calendar: return .permission(.calendar)
        case .bluetooth: return .permission(.bluetooth)
        case .audioCapture: return .systemAudio
        case .notifications: return .notifications
        case .automationFinder: return .finderAutomation
        case .automationTerminal: return .terminalAutomation
        case .automationSystemEvents: return .systemEventsAutomation
        case .filesAndFolders, .automationPlayback, .appManagement, .fullDiskAccess: return nil
        }
    }

    static func action(for permission: AppPermission, status: PermissionRowStatus,
                       requestAvailable: Bool) -> PermissionRowAction {
        guard status != .granted else { return .settings }
        if requestAvailable, request(for: permission) != nil { return .request }
        return status == .missing ? .settingsRequired : .settings
    }
}
