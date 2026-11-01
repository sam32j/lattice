import Foundation

enum PermissionRowActionPolicyTests {
    static func run(_ suite: TestSuite) {
        PermissionPortalDispatchTests.run(suite)
        PermissionPortalRefreshTests.run(suite)
        let manualOnly: Set<AppPermission> = [.filesAndFolders, .automationPlayback, .appManagement, .fullDiskAccess]
        for permission in AppPermission.allCases {
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .granted,
                requestAvailable: true) == .settings, "granted permissions use Settings without requesting again")
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .missing,
                requestAvailable: false) == .settingsRequired, "denied or unavailable requests use Settings")
            suite.expect(PermissionRowActionPolicy.action(for: permission, status: .unknown,
                requestAvailable: false) == .settings, "unknown status alone cannot cause a request")
            if manualOnly.contains(permission) {
                suite.expect(PermissionRowActionPolicy.request(for: permission) == nil
                             && PermissionRowActionPolicy.action(for: permission, status: .missing,
                                requestAvailable: true) == .settingsRequired,
                             "manual-only permissions cannot advertise an unimplemented request")
            } else {
                suite.expect(PermissionRowActionPolicy.request(for: permission) != nil
                             && PermissionRowActionPolicy.action(for: permission, status: .missing,
                                requestAvailable: true) == .request,
                             "every requestable permission can initiate access while missing")
                suite.expect(PermissionRowActionPolicy.action(for: permission, status: .unknown,
                    requestAvailable: true) == .request,
                    "an explicitly supported request remains available even when its grant cannot be read")
            }
        }
        suite.expect(PermissionRowActionPolicy.request(for: .camera) == .permission(.camera)
                     && PermissionRowActionPolicy.request(for: .bluetooth) == .permission(.bluetooth)
                     && PermissionRowActionPolicy.request(for: .audioCapture) == .systemAudio
                     && PermissionRowActionPolicy.request(for: .automationSystemEvents) == .systemEventsAutomation,
                     "Camera, Bluetooth, System Audio and System Events route to their own native request APIs")
    }
}
