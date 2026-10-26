// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum PermissionRowActionPolicyTests {
    static func run(_ suite: TestSuite) {
        for permission in AppPermission.allCases {
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .granted,
                requestAvailable: true) == .settings, "granted permissions have one quiet Settings action")
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .unknown,
                requestAvailable: true) == .settings, "unknown permission status never invites a speculative request")
        }
        for permission in [AppPermission.fullDiskAccess, .microphone, .calendar] {
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .missing,
                requestAvailable: true) == .request, "an available supported request uses the primary Request action")
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .missing,
                requestAvailable: false) == .settingsRequired, "denial replaces Request with the required Settings action")
        }
        for permission in [AppPermission.accessibility, .screenRecording, .audioCapture, .filesAndFolders,
                           .notifications, .automationFinder, .automationTerminal, .automationPlayback,
                           .camera, .appManagement, .bluetooth] {
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .missing,
                requestAvailable: true) == .settingsRequired,
                "permissions assigned a Settings-only row keep that action even if another feature can request them")
        }
    }
}
