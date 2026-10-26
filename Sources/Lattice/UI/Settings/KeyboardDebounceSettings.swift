import SwiftUI

extension KeyboardSettings {
    // MARK: - Keyboard Debounce Card

    var keyboardDebounceCard: some View {
        SettingsCard(title: l10n.s.keyDebounceName) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(symbol: "keyboard", title: l10n.s.keyDebounceEnable,
                            caption: l10n.s.keyDebounceCaption) {
                    PermissionGatedToggle(l10n.s.keyDebounceEnable, isOn: $debounceEnabled)
                        .labelsHidden()
                        .onChange(of: debounceEnabled) { _, value in
                            debounce.syncWithPreferences()
                            features.finishAvailabilityChange()
                            guard value, !permissions.accessibility else { return }
                            permissions.requestAccessibility()
                            permissions.openAccessibilitySettings()
                        }
                }

                if debounceEnabled {
                    SettingsControlRow(title: l10n.s.keyDebounceGlobalWindow) {
                        DebounceIntervalControl(value: globalWindowBinding)
                    }
                    .padding(.leading, settingsRowTextInset)
                    .disabled(!debounceEnabled)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.s.keyDebouncePerKeySection).font(.subheadline.weight(.semibold))
                            .help(l10n.s.keyDebouncePerKeyCaption)

                        if !keyWindows.isEmpty {
                            ForEach(keyWindows) { row in
                                HStack(spacing: 8) {
                                    Text(KeyboardDebounceKeyCatalog.label(for: row.keyCode))
                                        .font(.system(.body, design: .monospaced).weight(.semibold))
                                        .frame(minWidth: 28, minHeight: 28)
                                        .padding(.horizontal, 6)
                                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                                    Spacer(minLength: 12)
                                    DebounceIntervalControl(value: debounceBinding(for: row.keyCode))
                                    Button(l10n.s.keyDebounceRemoveKey) {
                                        removeWindow(for: row.keyCode)
                                    }
                                    .help(l10n.s.keyDebounceRemoveKey)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Picker(l10n.s.keyDebounceKeyLabel, selection: $selectedKeyCode) {
                                Text(l10n.s.keyDebounceKeyLabel).tag(Int64?.none)
                                ForEach(KeyboardDebounceKeyCatalog.available(excluding: Set(keyWindows.map(\.keyCode)))) { key in
                                    Text(key.label).tag(Optional(key.code))
                                }
                            }
                            .labelsHidden().pickerStyle(.menu)
                            .fixedSize()
                            .frame(width: 160, alignment: .leading)

                            Spacer(minLength: 12)
                            DebounceIntervalControl(value: $selectedWindow)

                            Button(l10n.s.keyDebounceAddKey) {
                                if let selectedKeyCode {
                                    setWindow(selectedWindow, for: selectedKeyCode)
                                    self.selectedKeyCode = nil
                                }
                            }
                            .disabled(!debounceEnabled || selectedKeyCode == nil)
                        }
                    }
                    .padding(.leading, settingsRowTextInset)
                    .disabled(!debounceEnabled)
                }
            }
        }
    }

    var globalWindowBinding: Binding<Int> {
        Binding {
            Defaults.sanitizedKeyboardDebounceWindow(globalWindow)
        } set: { value in
            globalWindow = Defaults.sanitizedKeyboardDebounceWindow(value)
            debounce.syncWithPreferences()
        }
    }

    var keyWindows: [KeyWindowRow] {
        KeyboardDebounceOverrides.decode(keyWindowsRaw)
            .map { KeyWindowRow(keyCode: $0.keyCode, window: $0.window) }
    }

    func debounceBinding(for keyCode: Int64) -> Binding<Int> {
        Binding {
            KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)[keyCode]
                ?? Defaults.defaultKeyboardDebounceWindowMs
        } set: { value in
            setWindow(value, for: keyCode)
        }
    }

    func setWindow(_ value: Int, for keyCode: Int64) {
        keyWindowsRaw = KeyboardDebounceOverrides.setting(value, for: keyCode, in: keyWindowsRaw)
        debounce.syncWithPreferences()
    }

    func removeWindow(for keyCode: Int64) {
        keyWindowsRaw = KeyboardDebounceOverrides.removing(keyCode, from: keyWindowsRaw)
        debounce.syncWithPreferences()
    }

}

struct DebounceIntervalControl: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = Defaults.allowedKeyboardDebounceWindowRange
    var step: Int = Defaults.keyboardDebounceWindowStep
    var onCommit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 5) {
            DebounceIntervalField(value: $value, range: range, onCommit: onCommit)
                .frame(width: 36, height: 20)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(height: 1)
                }
            Text("ms")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Stepper("", value: Binding(
                get: { value },
                set: {
                    value = $0
                    onCommit?()
                }
            ), in: range, step: step)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
    }
}

private struct DebounceIntervalField: NSViewRepresentable {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var onCommit: (() -> Void)?
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> Control {
        let field = Control()
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: Control, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = isEnabled
        if field.currentEditor() == nil {
            field.stringValue = String(value)
        }
    }

    static func dismantleNSView(_ field: Control, coordinator: Coordinator) {
        coordinator.stopClickOutsideMonitor()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Control: NSTextField {
        var clicked = false
        override var acceptsFirstResponder: Bool { clicked && isEnabled }
        override var needsPanelToBecomeKey: Bool { true }
        override func mouseDown(with event: NSEvent) {
            clicked = true
            window?.makeKey()
            window?.makeFirstResponder(self)
            super.mouseDown(with: event)
            (delegate as? Coordinator)?.startClickOutsideMonitor(for: self)
        }

        override func becomeFirstResponder() -> Bool {
            let ok = super.becomeFirstResponder()
            if ok {
                (delegate as? Coordinator)?.startClickOutsideMonitor(for: self)
            }
            return ok
        }

        override func resignFirstResponder() -> Bool {
            let ok = super.resignFirstResponder()
            if ok {
                (delegate as? Coordinator)?.stopClickOutsideMonitor()
            }
            return ok
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DebounceIntervalField
        private var clickMonitor: Any?

        init(_ parent: DebounceIntervalField) { self.parent = parent }

        deinit {
            stopClickOutsideMonitor()
        }

        func startClickOutsideMonitor(for field: Control) {
            guard clickMonitor == nil else { return }
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak field] event in
                guard let self, let field, let window = field.window else { return event }
                if event.window === window {
                    let localPoint = field.convert(event.locationInWindow, from: nil)
                    if !field.bounds.insetBy(dx: -2, dy: -2).contains(localPoint) {
                        self.stopClickOutsideMonitor()
                        window.makeFirstResponder(nil)
                    }
                } else {
                    self.stopClickOutsideMonitor()
                    window.makeFirstResponder(nil)
                }
                return event
            }
        }

        func stopClickOutsideMonitor() {
            guard let clickMonitor else { return }
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let field = notification.object as? Control else { return }
            startClickOutsideMonitor(for: field)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? Control,
                  let number = Int(field.stringValue),
                  parent.range.contains(number) else { return }
            parent.value = number
            parent.onCommit?()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            stopClickOutsideMonitor()
            guard let field = notification.object as? Control else { return }
            if let number = Int(field.stringValue) {
                parent.value = min(parent.range.upperBound, max(parent.range.lowerBound, number))
            }
            field.stringValue = String(parent.value)
            field.clicked = false
            parent.onCommit?()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
            if command == #selector(NSResponder.insertNewline(_:)) || command == #selector(NSResponder.cancelOperation(_:)) {
                stopClickOutsideMonitor()
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}
