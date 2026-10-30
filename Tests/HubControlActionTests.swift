import Foundation

/// Runs the production Hub action dispatcher without system actions or permission changes.
enum HubControlActionTests {
    enum QuickToggleAction: String { case emptyTrash }
    enum RunState { case needsPermission }
    static var events: [String] = []
    class ToggleState {
        var states: [QuickToggleAction: RunState] = [:]
        var denied: Bool {
            get { states[.emptyTrash] == .needsPermission }
            set { states[.emptyTrash] = newValue ? .needsPermission : nil }
        }
        func state(for action: QuickToggleAction) -> RunState? { denied ? .needsPermission : nil }
        func emptyTrash() { events.append("confirmTrash") }
        func toggleDarkMode() {}
        func toggleHiddenFiles() {}
        func toggleDesktopIcons() {}
        func ejectAllDisks() {}
        func lockScreen() {}
        func turnDisplayOff() {}
        func startScreenSaver() {}
    }
    struct PermissionSettings {
        func openAutomationSettings() { events.append("settings") }
    }
    enum Permissions { static let shared = PermissionSettings() }
    enum QuickTogglesService { static let shared = Toggles() }
    typealias MicMuteService = LatticeHubContract.MicMuteService
    enum KeepAwakeManager { static let shared = HubStayAwakeContract.Service() }
    typealias CleaningModeManager = LatticeHubContract.CleaningModeManager
    typealias DispatchQueue = LatticeHubContract.DispatchQueue
    final class BrightnessService {
        static let shared = BrightnessService()
        var keyboardLightEnabled: Bool? = true
        func setKeyboardLightEnabled(_ enabled: Bool) {}
    }

    enum CameraPreviewService { static let shared = Camera() }
    final class Camera {
        var isVisible = false, isEmbeddedPresented = false, routesToNotch = false
        func showInNotchIfEnabled() -> Bool {
            guard routesToNotch else { return false }
            isEmbeddedPresented = true; events.append("camera.notch"); return true
        }
        func show() { isVisible = true; events.append("camera.show") }
        func hide() { isVisible = false; isEmbeddedPresented = false; events.append("camera.hide") }
    }
    class PreferenceState {
        let defaults: UserDefaults
        var hiddenItemsRaw = ""
        struct Publisher { func send() {} }
        let objectWillChange = Publisher()
        init(_ defaults: UserDefaults) { self.defaults = defaults }
    }

    static func run(_ suite: TestSuite) {
        defer { QuickTogglesService.shared.denied = false; events = [] }
        events = []
        Action.emptyTrash.run { events.append("dismiss") }
        suite.expect(events == ["confirmTrash"],
                     "Trash confirmation keeps its Hub visible so cancellation and errors remain visible")
        events = []
        QuickTogglesService.shared.denied = true
        Action.emptyTrash.run { events.append("dismiss") }
        suite.expect(events == ["settings"] && !QuickTogglesService.shared.denied,
                     "denied Trash consent opens permission settings and allows a later retry")
        cameraControls(suite)
        cameraPreferences(suite)
    }

    private static func cameraControls(_ suite: TestSuite) {
        let camera = CameraPreviewService.shared
        defer {
            camera.isVisible = false; camera.isEmbeddedPresented = false; camera.routesToNotch = false
            DispatchQueue.main.jobs = []; events = []
        }
        let small = Action.rows([.cameraPreview, .keepAwake, .cleaningMode])
        suite.expect(small.first == [.keepAwake] && small.second == [.cameraPreview, .cleaningMode],
                     "camera and operational controls keep their secondary row with few visible controls")
        let first: [Action] = [.micMute, .keepAwake, .darkMode, .keyboardLight, .hiddenFiles, .desktopIcons]
        let full = Action.rows(first + [.emptyTrash, .ejectDisks, .lockScreen, .displayOff, .screenSaver, .cleaningMode, .cameraPreview])
        suite.expect(full.first == first && full.second == [.cameraPreview, .cleaningMode, .ejectDisks, .emptyTrash,
                                                              .lockScreen, .displayOff, .screenSaver],
                     "the second row follows the requested order while preserving primary toggles")
        events = []
        Action.cameraPreview.run { events.append("dismiss") }
        suite.expect(events == ["dismiss"] && DispatchQueue.main.jobs.count == 1,
                     "a floating camera opens only after the Hub dismisses")
        DispatchQueue.main.drain()
        suite.expect(events == ["dismiss", "camera.show"], "the camera quick control opens the floating preview")
        events = []
        Action.cameraPreview.run { events.append("dismiss") }
        suite.expect(events == ["camera.hide"] && !camera.isVisible, "a second activation hides the floating preview")
        camera.routesToNotch = true
        events = []
        Action.cameraPreview.run { events.append("dismiss") }
        suite.expect(events == ["camera.notch", "dismiss"] && DispatchQueue.main.jobs.isEmpty,
                     "camera routing transfers to the island without a delayed reopen")
        events = []
        Action.cameraPreview.run { events.append("dismiss") }
        suite.expect(events == ["camera.hide"] && !camera.isEmbeddedPresented,
                     "the quick control can stop an embedded preview")
    }

    private static func cameraPreferences(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.hub-camera.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let controls = ControlPreferences(defaults)
        controls.hiddenItemsRaw = "cameraPreview,cleaner"
        suite.expect(controls.hiddenControlsSet.contains(.cameraPreview), "a hidden camera tile stays hidden after moving")
        controls.setControlHidden(.cameraPreview, false)
        suite.expect(!controls.hiddenControlsSet.contains(.cameraPreview)
            && defaults.string(forKey: DefaultsKey.quickLauncherHiddenItems) == "cleaner",
            "showing the camera control retires its legacy hidden tile entry and preserves other hidden tiles")
        controls.setControlHidden(.cameraPreview, true)
        suite.expect(controls.hiddenControlsSet.contains(.cameraPreview), "camera now persists in hidden quick controls")
    }
}
