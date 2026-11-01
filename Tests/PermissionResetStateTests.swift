import Foundation

enum PermissionResetStateTests {
    enum CopyKey { case restartButton, restartTitle, restartDescription, clearTitle, confirmation, clearButton }
    enum ModalResponse { case alertFirstButtonReturn, alertSecondButtonReturn }
    final class Alert {
        enum Style { case warning, informational }
        static var shown: [Alert] = []
        static var response = ModalResponse.alertFirstButtonReturn
        var alertStyle = Style.informational
        var messageText = "", informativeText = ""
        var buttons: [String] = []
        final class ActionButton { var hasDestructiveAction = false }
        @discardableResult
        func addButton(withTitle title: String) -> ActionButton { buttons.append(title); return ActionButton() }
        func runModal() -> ModalResponse { Self.shown.append(self); return Self.response }
    }
    class DialogState {
        let state: PermissionResetState
        var showingRestartDialog = false
        var restarts = 0
        var restartDialogEnabled = true
        var reminders: [() -> Void] = []
        func scheduleRestartReminder(_ action: @escaping () -> Void) { reminders.append(action) }
        var needsRestart: Bool { state.phase == .restartRequired || state.phase == .failed }
        init(_ phase: PermissionResetState.Phase) { state = PermissionResetState(phase: phase) }
        func copy(_ key: CopyKey) -> String {
            switch key {
            case .clearTitle: return "Clear All Permissions"
            case .confirmation: return "Reset permissions?"
            case .clearButton: return "Clear"
            case .restartButton: return "Restart"
            case .restartTitle: return "Restart Lattice"
            case .restartDescription: return "Restart Lattice to finish permission reset."
            }
        }
        func restart() { restarts += 1 }
        func runPermissionAlert(_ alert: Alert) -> ModalResponse { alert.runModal() }
        var cancelTitle: String { "Cancel" }
    }
    static func run(_ suite: TestSuite) {
        PermissionDialogPresentationTests.run(suite)
        Alert.shown = []
        DialogPresenter(.ready).presentRestartIfNeeded()
        DialogPresenter(.working).presentRestartIfNeeded()
        suite.expect(Alert.shown.isEmpty, "reset completion dialog never appears before reset finishes")
        let completed = DialogPresenter(.restartRequired)
        completed.presentRestartIfNeeded()
        suite.expect(Alert.shown.last?.messageText == "Restart Lattice"
                     && Alert.shown.last?.informativeText == "Restart Lattice to finish permission reset."
                     && Alert.shown.last?.buttons == ["Restart"] && completed.restarts == 1,
                     "successful reset requires a modal restart with existing title and help, without a Later action")
        completed.presentRestartIfNeeded()
        suite.expect(Alert.shown.count == 1, "duplicate lifecycle updates cannot stack restart dialogs")
        suite.expect(completed.reminders.count == 1, "a relaunch that returns leaves a scheduled required restart retry")
        completed.reminders.first?()
        suite.expect(completed.restarts == 2 && Alert.shown.count == 2,
                     "an app still alive after relaunch receives another required restart action")
        let probe = DialogPresenter(.restartRequired)
        probe.restartDialogEnabled = false
        probe.presentRestartIfNeeded()
        suite.expect(Alert.shown.count == 2 && probe.restarts == 0 && probe.reminders.isEmpty,
                     "rendering fixtures can explicitly suppress native restart dialogs and retries")
        let failed = DialogPresenter(.failed)
        failed.presentRestartIfNeeded()
        suite.expect(Alert.shown.last?.messageText == "Restart Lattice"
                     && Alert.shown.last?.informativeText == "Restart Lattice to finish permission reset."
                     && Alert.shown.last?.buttons == ["Restart"] && failed.restarts == 1,
                     "both reset outcomes use the requested restart title and help")
        Alert.shown = []
        let confirmation = DialogPresenter(.ready)
        Alert.response = .alertSecondButtonReturn
        suite.expect(!confirmation.confirmReset() && Alert.shown.last?.buttons == ["Clear", "Cancel"],
                     "native reset confirmation supports Cancel without approving a reset")
        Alert.response = .alertFirstButtonReturn
        suite.expect(confirmation.confirmReset() && Alert.shown.last?.messageText == "Clear All Permissions"
                     && Alert.shown.last?.informativeText == "Reset permissions?",
                     "native confirmation and restart dialogs use the same presentation boundary")
        let state = PermissionResetState()
        var finish: ((Bool) -> Void)?
        var requests = 0
        suite.expect(state.phase == .ready, "permission reset starts with a clear action, not a restart claim")
        state.begin { completion in requests += 1; finish = completion }
        state.begin { _ in requests += 1 }
        suite.expect(state.phase == .working && requests == 1, "reset confirmation starts exactly one operation while pending")
        finish?(false)
        suite.expect(state.phase == .failed, "a failed reset never claims all permissions were cleared")
        state.begin { completion in requests += 1; finish = completion }
        finish?(true)
        state.begin { _ in requests += 1 }
        suite.expect(state.phase == .restartRequired && requests == 2,
                     "successful reset becomes a restart action and cannot reset again before restart")
        let domain = "io.github.sam32j.lattice.tests.reset-configuration.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: DefaultsKey.keyboardDebounceEnabled)
        defaults.set("saved-keyboard-shortcut", forKey: DefaultsKey.cleaningModeShortcut)
        defaults.set(BrightnessSupport.KeyStep.quarter.rawValue, forKey: DefaultsKey.brightnessKeyStep)
        let reset = PermissionResetState()
        reset.begin { complete in
            let verified = PermissionRevocationPolicy.revalidated([.accessibility: false], verify: { _ in false })
            _ = PermissionRevocationPolicy.apply(verified, in: defaults)
            complete(true)
        }
        suite.expect(reset.phase == .restartRequired && !defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
                     && defaults.string(forKey: DefaultsKey.cleaningModeShortcut) == "saved-keyboard-shortcut"
                     && defaults.string(forKey: DefaultsKey.brightnessKeyStep) == BrightnessSupport.KeyStep.quarter.rawValue,
                     "reset and verified revocation disable restricted activation but retain saved shortcuts and tuning")
        _ = PermissionRevocationPolicy.apply([.accessibility: true], in: defaults)
        suite.expect(BrightnessKeyStepReader(defaults: defaults).keyStep == .standard
                     && defaults.string(forKey: DefaultsKey.brightnessKeyStep) == BrightnessSupport.KeyStep.quarter.rawValue,
                     "restoring permission retains Quarter tuning without rearming finer-step interception")
        let backup = SettingsBackupSupport.payload(appVersion: "test", valueFor: defaults.object(forKey:))
        let restored = SettingsBackupSupport.sanitizedSettings(from: backup) ?? [:]
        let restoredDomain = "io.github.sam32j.lattice.tests.reset-configuration-restored.\(UUID())"
        let restoredDefaults = UserDefaults(suiteName: restoredDomain)!
        defer { restoredDefaults.removePersistentDomain(forName: restoredDomain) }
        restored.forEach { restoredDefaults.set($0.value, forKey: $0.key) }
        suite.expect(restoredDefaults.string(forKey: DefaultsKey.brightnessKeyStep) == "quarter"
                     && BrightnessKeyStepReader(defaults: restoredDefaults).keyStep == .standard,
                     "exporting and restoring paused Quarter tuning never rearms interception")
    }
}
