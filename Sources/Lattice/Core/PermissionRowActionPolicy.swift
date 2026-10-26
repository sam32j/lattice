// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum PermissionRowStatus { case granted, missing, unknown }
enum PermissionRowAction { case request, settings, settingsRequired }

enum PermissionRowActionPolicy {
    static func action(for permission: AppPermission, status: PermissionRowStatus,
                       requestAvailable: Bool) -> PermissionRowAction {
        guard status == .missing else { return .settings }
        switch permission {
        case .fullDiskAccess, .microphone, .calendar:
            return requestAvailable ? .request : .settingsRequired
        default:
            return .settingsRequired
        }
    }
}
