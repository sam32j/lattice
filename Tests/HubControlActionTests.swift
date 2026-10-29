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
    typealias KeepAwakeManager = LatticeHubContract.KeepAwakeManager
    typealias CleaningModeManager = LatticeHubContract.CleaningModeManager
    typealias DispatchQueue = LatticeHubContract.DispatchQueue
    final class BrightnessService {
        static let shared = BrightnessService()
        var keyboardLightEnabled: Bool? = true
        func setKeyboardLightEnabled(_ enabled: Bool) {}
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
    }
}
