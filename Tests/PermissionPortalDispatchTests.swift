import Foundation

enum PermissionPortalDispatchTests {
    static var events: [String] = []
    static var audioResult = SystemAudioAccessResult.denied
    static var replies: [() -> Void] = []
    class State {
        let permission: AppPermission
        var requestingMicrophone = false
        var requesting: Bool {
            get { requestingMicrophone }
            set { requestingMicrophone = newValue }
        }
        var attemptedManualRequest = false, requestInFlight = false
        var status = PermissionRowStatus.unknown
        var audioRequest: FeatureWorkCancellation?
        var finished = 0
        var onRequestFinished: () -> Void = { events.append("finished") }
        init(_ permission: AppPermission) { self.permission = permission }
    }
    enum SettingsPermissionAccess {
        static func request(_ permission: SettingsPermission, completion: @escaping (SettingsPermissionResult) -> Void) {
            events.append("native:\(permission)")
            replies.append { completion(.denied) }
        }
    }
    final class Permissions {
        static let shared = Permissions()
        enum AutomationTarget: String { case finder, terminal, systemEvents }
        func requestAccessibility(offerSettingsRecovery: Bool = true) { events.append("native:accessibility") }
        func requestScreenRecording(offerSettingsRecovery: Bool = true) { events.append("native:screenRecording") }
        func openAccessibilitySettings() { events.append("accessibility-settings") }
        func openScreenRecordingSettings() { events.append("screen-settings") }
        func openFilesAndFoldersSettings() { events.append("settings") }
        func openNotificationSettings() { events.append("settings") }
        func openAutomationSettings() { events.append("settings") }
        func openMicrophoneSettings() { events.append("settings") }
        func openCalendarSettings() { events.append("settings") }
        func openCameraSettings() { events.append("settings") }
        func openAppManagementSettings() { events.append("settings") }
        func openAudioCaptureSettings() { events.append("audio-settings") }
        func requestFullDiskAccess() { events.append("disk") }
        func openFullDiskAccessSettings() { events.append("disk-settings") }
        func requestCalendar() { events.append("calendar") }
        func refresh() { events.append("refresh") }
        func requestMicrophone(completion: @escaping (Bool) -> Void) {
            events.append("native:microphone")
            replies.append { completion(false) }
        }
        static func requestAutomation(_ target: AutomationTarget, completion: @escaping (Bool) -> Void) {
            events.append("automation:\(target.rawValue)")
            replies.append { completion(false) }
        }
    }
    enum SystemAudioRecordingAccess {
        @discardableResult
        static func request(completion: @escaping (SystemAudioAccessResult) -> Void) -> FeatureWorkCancellation {
            events.append("audio")
            replies.append { completion(audioResult) }
            return FeatureWorkCancellation()
        }
    }
    final class BluetoothPermissionAccess {
        static let shared = BluetoothPermissionAccess()
        func openSettings() { events.append("settings") }
    }
    enum Notifier {
        static func requestPermission(completion: ((Bool) -> Void)? = nil) {
            events.append("notifications")
            replies.append { completion?(false) }
        }
    }
    enum NativeRequestAdapter {
        static var granted = false
        static var attemptedAccessibility = false
        static func isGranted(_ permission: SettingsPermission) -> Bool { granted }
        static func showRecovery(_ permission: SettingsPermission) { events.append("offer:\(permission)") }
    }
    static func run(_ suite: TestSuite) {
        for (permission, expected) in [(SettingsPermission.accessibility, "native:accessibility"),
                                      (.screenRecording, "native:screenRecording")] {
            events = []
            var result: SettingsPermissionResult?
            NativeRequestAdapter.granted = false
            NativeRequestAdapter.request(permission) { result = $0 }
            suite.expect(events == [expected] && result == .needsSettings,
                         "native request for \(permission) never opens Settings before the user chooses it")
            events = []
            NativeRequestAdapter.granted = true
            NativeRequestAdapter.request(permission) { result = $0 }
            suite.expect(events == [expected] && result == .granted,
                         "native request for \(permission) preserves verified successful activation")
            events = []
            NativeRequestAdapter.granted = false
            NativeRequestAdapter.attemptedAccessibility = false
            NativeRequestAdapter.requestWithRecovery(permission)
            suite.expect(events == (permission == .accessibility ? [expected] : [expected, "offer:\(permission)"]),
                         "asynchronous Accessibility consent is not mistaken for an immediate denial")
            if permission == .accessibility {
                events = []
                NativeRequestAdapter.requestWithRecovery(permission)
                suite.expect(events == ["offer:accessibility"],
                             "an explicit Accessibility retry offers Settings without another native prompt")
            }
            events = []
            NativeRequestAdapter.granted = true
            NativeRequestAdapter.requestWithRecovery(permission)
            suite.expect(events == [expected], "successful direct requests offer no unnecessary recovery")
        }
        for (permission, expected) in [
            (AppPermission.camera, "native:camera"), (.bluetooth, "native:bluetooth"),
            (.accessibility, "native:accessibility"), (.screenRecording, "native:screenRecording"),
            (.microphone, "native:microphone"), (.audioCapture, "audio"),
            (.notifications, "notifications"), (.automationFinder, "automation:finder"),
            (.automationTerminal, "automation:terminal"),
            (.automationSystemEvents, "automation:systemEvents") ] {
            events = []; replies = []
            let row = Row(permission)
            row.request()
            suite.expect(events == [expected] && row.requesting,
                         "Request for \(permission) invokes its native request and waits for completion")
            row.request()
            suite.expect(events == [expected], "pending \(permission) requests cannot be duplicated")
            replies.first?()
            suite.expect(!row.requesting && events.contains("refresh") && events.contains("finished"),
                         "completing \(permission) refreshes status and releases the button")
        }
        events = []; replies = []; audioResult = .needsSettings
        let deniedAudioRow = Row(.audioCapture)
        deniedAudioRow.request()
        replies.first?()
        suite.expect(!events.contains("audio-settings") && !deniedAudioRow.requesting,
                     "denied audio portal retry never opens Settings without a button click")
        audioResult = .denied
        for (permission, expected) in [(AppPermission.fullDiskAccess, "disk"), (.calendar, "calendar")] {
            events = []; replies = []
            Row(permission).request()
            suite.expect(events == [expected], "existing \(permission) request entry point stays available")
        }
        events = []
        let grantedDisk = Row(.fullDiskAccess)
        grantedDisk.status = .granted
        grantedDisk.openSystemSettings()
        suite.expect(events == ["disk-settings"], "granted Full Disk Access opens Settings without probing protected files")
    }
}
