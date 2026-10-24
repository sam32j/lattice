import Foundation

enum CameraPermissionRevocationTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.camera-revocation.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: AppFeature.cameraPreview.availabilityKey)
        defaults.set("saved-camera-shortcut", forKey: DefaultsKey.cameraPreviewShortcut)
        defaults.set(true, forKey: DefaultsKey.notchCameraEnabled)
        let changes = PermissionRevocationPolicy.apply([.camera: false], in: defaults)
        suite.expect(!defaults.bool(forKey: AppFeature.cameraPreview.availabilityKey)
                     && changes.affected.contains(.cameraPreview),
                     "Camera revocation switches off the actual page-owned enable flag and schedules service teardown")
        suite.expect(defaults.string(forKey: DefaultsKey.cameraPreviewShortcut) == "saved-camera-shortcut"
                     && defaults.bool(forKey: DefaultsKey.notchCameraEnabled),
                     "revocation preserves the saved shortcut and island configuration")
        _ = PermissionRevocationPolicy.apply([.camera: true], in: defaults)
        suite.expect(!defaults.bool(forKey: AppFeature.cameraPreview.availabilityKey),
                     "restoring Camera access alone never re-enables the feature")
    }
}
