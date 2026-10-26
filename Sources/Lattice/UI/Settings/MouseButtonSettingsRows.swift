import SwiftUI

extension MouseButtonShortcutsSection {
    // MARK: - Rows

    func mappingRow(_ button: Int64, shortcut: GlobalShortcut?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(MouseButtonShortcutSupport.buttonName(for: button, strings: text))
                Spacer()
                CompactShortcutBindingRecorder(
                    recordingID: "mouse-button-\(button)",
                    shortcut: shortcut,
                    isEnabled: true,
                    emptyTitle: text.setShortcutButton,
                    canClear: shortcut != nil,
                    errorText: Binding(
                        get: { recordErrorButton == button ? recordError : nil },
                        set: { setRecordError($0, button) }),
                    onClear: { remove(button) },
                    onReset: {},
                    onCapture: { save(button: button, shortcut: $0) },
                    onRecordingChange: { recordingButton = $0 ? button : nil })
            }
            if let recordError, recordErrorButton == button {
                Text(recordError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if recordingButton == button {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if shortcut != nil, RadialMenuSupport.claimsMouseButton(button) {
                Text(text.rowWheelNote)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if shortcut != nil { MouseShortcutExceptionEditor(button: button) }
        }
    }

    @ViewBuilder
    var captureRow: some View {
        if capturing {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if service.isRunning {
                        Image(systemName: "circle.dashed")
                            .foregroundStyle(.secondary)
                        Text(text.captureWaiting)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text(text.captureBlind)
                        Button("Retry") { service.setCapturing(true) }
                    }
                    Spacer()
                    Button(text.captureCancel) { stopCapture() }
                }
                if let captureFeedback {
                    Text(captureFeedback)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(text.captureHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onReceive(service.$lastInputSeen) { seen in
                handleCapture(seen)
            }
        } else {
            Button {
                startCapture()
            } label: {
                Label(text.configureButton(l10n.language), systemImage: "plus")
            }
        }
    }

    /// The bound button, the capture in progress, or the invitation to pick
    /// one. The same capture the shortcut rows use, so the button is named by
    /// pressing it rather than by counting.
    @ViewBuilder
    var spacesRow: some View {
        if spacesCapturing {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if service.isRunning {
                        Image(systemName: "circle.dashed")
                            .foregroundStyle(.secondary)
                        Text(text.spacesCaptureWaiting)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text(text.captureBlind)
                        Button("Retry") { service.setCapturing(true) }
                    }
                    Spacer()
                    Button(text.captureCancel) { stopSpacesCapture() }
                }
                if let spacesFeedback {
                    Text(spacesFeedback)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .onReceive(service.$lastInputSeen) { seen in
                handleSpacesCapture(seen)
            }
        } else if spacesButton != 0 {
            HStack(spacing: 8) {
                Text(MouseButtonShortcutSupport.buttonName(for: Int64(spacesButton), strings: text))
                Spacer()
                Button {
                    spacesButton = 0
                    MouseButtonShortcutService.shared.syncWithPreferences()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(text.removeButton)
                .accessibilityLabel(text.removeButton)
            }
        } else {
            Button {
                startSpacesCapture()
            } label: {
                Label(text.spacesPickButton, systemImage: "plus")
            }
        }
    }

    /// Whether the system still has a combination registered for any of the
    /// four commands the drag asks for. With all four switched off there is
    /// nothing left to press, which is worth saying out loud.
    var spacesCommandsAreReachable: Bool {
        SpaceWindowBridge.spaceShortcut(.left) != nil
            || SpaceWindowBridge.spaceShortcut(.right) != nil
            || SpaceWindowBridge.overviewShortcut(.missionControl) != nil
            || SpaceWindowBridge.overviewShortcut(.appExpose) != nil
    }

}
