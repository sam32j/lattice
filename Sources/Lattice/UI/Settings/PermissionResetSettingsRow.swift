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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(needsRestart ? copy(.restartTitle) : l10n.s.advancedClearButton).font(.body)
                Text(copy(needsRestart ? .restartDescription : .description))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if state.phase == .failed {
                    Label(l10n.s.advancedClearFailed, systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if needsRestart {
                Button(action: restart) { Text(copy(.restartButton)).frame(minWidth: 100) }
                    .buttonStyle(.bordered).foregroundStyle(.secondary)
            } else {
                Button(role: .destructive) { confirming = true } label: {
                    Text(copy(.clearButton)).frame(minWidth: 100)
                }.buttonStyle(.bordered).foregroundStyle(.red).disabled(state.phase == .working)
            }
        }
        .controlSize(.regular)
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
