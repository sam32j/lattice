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

    /// The Configure button and the capture it opens share one slot. Both
    /// stay laid out and cross-fade while the slot's height eases between
    /// them, clipped, so nothing pops in at full size or jumps once the
    /// other side has finished fading.
    var captureRow: some View {
        ZStack(alignment: .topTrailing) {
            captureDetails
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    // A note arriving mid-capture grows the slot with it.
                    withAnimation(captureDetailsHeight == nil || reduceMotion ? nil : .settingsExpansion) {
                        captureDetailsHeight = height
                    }
                }
                .opacity(capturing ? 1 : 0)
                .allowsHitTesting(capturing)
                // Hidden from hit testing is not hidden from accessibility:
                // the folded Cancel sat under Configure and took its press.
                .disabled(!capturing)
                .accessibilityHidden(!capturing)
            Button {
                startCapture()
            } label: {
                Label(text.configureButton(l10n.language), systemImage: "plus")
            }
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { configureButtonHeight = $0 }
            .opacity(capturing ? 0 : 1)
            .allowsHitTesting(!capturing)
            .disabled(capturing)
            .accessibilityHidden(capturing)
        }
        .frame(height: capturing ? captureDetailsHeight : configureButtonHeight, alignment: .top)
        .clipped()
        .onReceive(service.$lastInputSeen) { seen in
            handleCapture(seen)
        }
    }

    /// The prompt with its hint right under it, and Cancel beside them. A
    /// refused press replaces both with one amber line instead of stacking
    /// a third line below them.
    private var captureDetails: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let captureFeedback {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(captureFeedback)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if service.isRunning || !capturing {
                // While the slot fades out after Cancel the service has
                // already stopped watching; keep showing the waiting prompt
                // rather than flashing "cannot watch the mouse".
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.captureWaiting)
                    Text(text.captureHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text(text.captureBlind)
                Button("Retry") { service.setCapturing(true) }
            }
            Spacer(minLength: 8)
            Button(text.captureCancel) { stopCapture() }
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
