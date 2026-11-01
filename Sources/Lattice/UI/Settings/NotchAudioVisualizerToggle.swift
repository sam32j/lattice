import SwiftUI

/// The permission request belongs to this explicit child control only.
struct NotchAudioVisualizerToggle: View {
    let title: String
    let caption: String
    @Binding var isOn: Bool
    let contextEnabled: Bool
    @State private var showsPermissionInfo = false
    @StateObject private var activation: NotchVisualizerActivation
    @ObservedObject private var reset = PermissionResetState.shared
    @ObservedObject private var l10n = L10n.shared

    init(_ title: String, caption: String, isOn: Binding<Bool>, contextEnabled: Bool) {
        self.title = title; self.caption = caption
        self._isOn = isOn; self.contextEnabled = contextEnabled
        _activation = StateObject(wrappedValue: NotchVisualizerActivation(
            request: SystemAudioRecordingAccess.request,
            verify: SystemAudioRecordingAccess.check,
            openSettings: Permissions.shared.openAudioCaptureSettings,
            canEnable: {
                PermissionResetState.shared.phase == .ready && NotchSupport.isEnabled()
                    && NotchSupport.modules().contains(.music)
            }, apply: { isOn.wrappedValue = $0 }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsRow(symbol: "waveform", title: title, caption: caption) {
                HStack(spacing: 8) {
                    if activation.requesting { ProgressView().controlSize(.mini) }
                    Toggle(title, isOn: Binding(get: { isOn }, set: activation.setEnabled))
                        .labelsHidden().toggleStyle(.switch)
                        .disabled(activation.requesting || !contextEnabled || reset.phase != .ready)
                }
            }
        }
        .onChange(of: activation.failed) { _, failed in
            showsPermissionInfo = failed
        }
        .alert(l10n.s.permissionRequired, isPresented: $showsPermissionInfo) {
            Button(l10n.s.permissionOpenSettings, action: activation.openSettingsForRecovery)
            Button(l10n.s.mediaCancel, role: .cancel) {}
        } message: {
            Text(FeatureStrings.hub(l10n.language).explainAudioCapture + "\n\n" + l10n.s.permissionRestartNote)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            activation.returnedToApplication()
        }
        .onDisappear { showsPermissionInfo = false; activation.cancel() }
        .onChange(of: contextEnabled) { _, enabled in if !enabled { activation.setEnabled(false) } }
        .onChange(of: reset.phase) { _, phase in if phase != .ready { activation.cancel() } }
    }
}
