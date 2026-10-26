import SwiftUI

struct PermissionResetSettingsRow: View {
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var state: PermissionResetState
    @State private var confirming = false
    let reset: (@escaping (Bool) -> Void) -> Void
    let restart: () -> Void
    let onWorkingChange: (Bool) -> Void

    init(state: PermissionResetState = .shared,
         reset: @escaping (@escaping (Bool) -> Void) -> Void = SelfUninstall.clearPermissions,
         restart: @escaping () -> Void = { FeatureRuntime.shared.relaunchApp() },
         onWorkingChange: @escaping (Bool) -> Void = { _ in }) {
        _state = StateObject(wrappedValue: state)
        self.reset = reset; self.restart = restart
        self.onWorkingChange = onWorkingChange
    }

    private var needsRestart: Bool { state.phase == .restartRequired }
    private func copy(_ key: PermissionResetCopy.Key) -> String { PermissionResetCopy.text(key, l10n.language) }

    var body: some View {
        DataPermissionsRow(symbol: needsRestart ? "arrow.clockwise" : "arrow.counterclockwise",
            title: needsRestart ? copy(.restartTitle) : l10n.s.advancedClearButton,
            description: state.phase == .failed ? l10n.s.advancedClearFailed
                : copy(needsRestart ? .restartDescription : .description),
            tone: needsRestart ? .neutral : .destructive,
            descriptionIsError: state.phase == .failed,
            actionTitle: copy(needsRestart ? .restartButton : .clearButton),
            actionTone: needsRestart ? .quiet : .destructive,
            actionRole: needsRestart ? nil : .destructive,
            actionEnabled: state.phase != .working) {
                if needsRestart { restart() } else { confirming = true }
            }
        .onAppear { onWorkingChange(state.phase == .working) }
        .onChange(of: state.phase) { _, phase in onWorkingChange(phase == .working) }
        .alert(copy(.clearTitle),
               isPresented: $confirming) {
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(copy(.clearButton), role: .destructive) {
                state.begin(using: reset)
            }
        } message: {
            Text(copy(.confirmation))
        }
    }
}
