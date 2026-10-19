import Foundation

enum SettingsResetAvailabilityTests {
    class State {
        var action = WindowLayoutAction.leftHalf
        var shortcut = WindowLayoutAction.leftHalf.defaultShortcut
        var actionsEnabled = false
        var shortcutsEnabled = false
    }
    static func run(_ suite: TestSuite) {
        func verify(_ state: State, offersReset: () -> Bool, page: String) {
            suite.expect(!offersReset(), "\(page) offers no no-op Reset for a paused default binding")
            state.shortcut = GlobalShortcut(keyCode: 18, modifiers: [.control, .command])
            suite.expect(offersReset(), "\(page) offers Reset for a customized binding even while paused")
            state.shortcut = nil
            suite.expect(offersReset(), "\(page) offers Reset to restore a cleared default binding")
            state.action = .fullScreen
            suite.expect(!offersReset(), "\(page) offers no Reset when both binding and default are empty")
        }
        let layout = Layout(), central = Central()
        verify(layout, offersReset: { layout.offersReset }, page: "Window Layout")
        verify(central, offersReset: { central.offersReset }, page: "Keyboard Shortcuts")
    }
}
