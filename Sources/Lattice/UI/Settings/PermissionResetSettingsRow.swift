import SwiftUI

struct PermissionResetSettingsRow: View {
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var state: PermissionResetState
    @State private var dialogWindow = PermissionDialogWindowReference()
    @State private var showingRestartDialog = false
    @State private var restartAttemptReturned = false
    let reset: (@escaping (Bool) -> Void) -> Void
    let restart: () -> Void
    let restartDialogEnabled: Bool
    let scheduleRestartReminder: (@escaping () -> Void) -> Void
    let onWorkingChange: (Bool) -> Void

    init(state: PermissionResetState = .shared,
         reset: @escaping (@escaping (Bool) -> Void) -> Void = SelfUninstall.clearPermissions,
         restart: @escaping () -> Void = { FeatureRuntime.shared.relaunchApp() },
         restartDialogEnabled: Bool = true,
         scheduleRestartReminder: @escaping (@escaping () -> Void) -> Void = { action in
             DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: action)
         },
         onWorkingChange: @escaping (Bool) -> Void = { _ in }) {
        _state = StateObject(wrappedValue: state)
        self.reset = reset; self.restart = restart
        self.restartDialogEnabled = restartDialogEnabled
        self.scheduleRestartReminder = scheduleRestartReminder
        self.onWorkingChange = onWorkingChange
    }

    private var needsRestart: Bool { state.phase == .restartRequired || state.phase == .failed }
    private func copy(_ key: PermissionResetCopy.Key) -> String { PermissionResetCopy.text(key, l10n.language) }

    var body: some View {
        DataPermissionsRow(symbol: "arrow.counterclockwise",
            title: l10n.s.advancedClearButton,
            description: resetDescription,
            tone: .destructive,
            descriptionIsError: state.phase == .failed,
            descriptionLineLimit: needsRestart ? nil : 2,
            actionTitle: needsRestart ? copy(.restartButton) : copy(.clearButton),
            actionTone: .destructive,
            actionRole: .destructive,
            actionEnabled: state.phase == .ready || (needsRestart && restartAttemptReturned)) {
                if needsRestart { restart(); return }
                guard confirmReset() else { return }
                beginReset()
            }
        .background(PermissionDialogWindowReader(reference: dialogWindow))
        .onAppear {
            onWorkingChange(state.phase == .working)
            DispatchQueue.main.async { presentRestartIfNeeded() }
        }
        .onChange(of: state.phase) { _, phase in
            onWorkingChange(phase == .working)
            // Let the confirmation close before presenting an app-modal restart requirement.
            DispatchQueue.main.async { presentRestartIfNeeded() }
        }
    }

    private var cancelTitle: String { l10n.s.uninstallerCancel }

    private var resetDescription: String {
        var message = state.phase == .failed ? l10n.s.advancedClearFailed
            : needsRestart ? copy(.restartDescription) : copy(.description)
        if restartAttemptReturned {
            message += "\n" + PermissionResetCopy.manualRestart(l10n.language)
        }
        return message
    }

    private func makePermissionAlert(_ title: String, message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        return alert
    }

    private func runPermissionAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        PermissionDialogPresentation.run(alert, over: dialogWindow.window ?? NSApp.mainWindow)
    }

    private func confirmReset() -> Bool {
        guard state.phase == .ready else { return false }
        let alert = makePermissionAlert(copy(.clearTitle), message: copy(.confirmation))
        // Use the standard native primary action so Clear has a stable, visible
        // label in the current glass alert renderer. Confirmation still gates reset.
        alert.addButton(withTitle: copy(.clearButton))
        alert.addButton(withTitle: cancelTitle)
        return runPermissionAlert(alert) == .alertFirstButtonReturn
    }

    private func beginReset() {
        state.begin(using: { completion in
            SystemAudioRecordingAccess.cancelPending()
            NotchVisualizerActivation.disableForPermissionReset()
            NotchVisualizerRuntime.syncWithPreferences()
            reset { succeeded in
                if succeeded {
                    let allPermissions: [SettingsPermission: Bool] = [
                        .accessibility: false,
                        .screenRecording: false,
                        .camera: false,
                        .microphone: false,
                        .calendar: false,
                        .bluetooth: false
                    ]
                    let changes = PermissionRevocationPolicy.apply(allPermissions, in: .standard)
                    if !changes.affected.isEmpty {
                        FeatureRuntime.shared.sync(Array(changes.affected))
                        FeatureRuntime.shared.finishAvailabilityChange()
                    }
                    UserDefaults.standard.removeObject(forKey: "permissionRevocationObservedGrants")
                }
                completion(succeeded)
            }
        })
    }

    private func presentRestartIfNeeded() {
        guard restartDialogEnabled, needsRestart, !showingRestartDialog, !restartAttemptReturned else { return }
        showingRestartDialog = true
        let alert = makePermissionAlert(copy(.restartTitle), message: copy(.restartDescription))
        alert.addButton(withTitle: copy(.restartButton))
        // There is no Later/Cancel action: permission-dependent work is paused until relaunch.
        if runPermissionAlert(alert) == .alertFirstButtonReturn {
            restart()
        }
        // Successful termination ends this process. If relaunch fails or quitting is
        // vetoed, expose a persistent action and manual instructions in the row.
        scheduleRestartReminder {
            showingRestartDialog = false
            restartAttemptReturned = true
        }
    }

}

