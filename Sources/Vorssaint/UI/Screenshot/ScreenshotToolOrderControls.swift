// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Reusable controls for screenshot tool order and shortcut assignments.
struct ScreenshotToolOrderControls: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var shortcutsEnabled: Bool
    var showsTitle = true
    @AppStorage(DefaultsKey.screenshotToolShortcuts) private var bindingsRaw = ""
    @State private var recordingTool: ScreenshotSupport.Tool?
    @State private var errorText: String?
    @StateObject private var keyboard = ScreenshotShortcutContext()

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var orderedTools: [ScreenshotSupport.Tool] {
        ScreenshotSupport.Tool.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text(strings.toolShortcutsTitle)
                    .font(.headline)
            }

            Toggle(strings.toolShortcutsToggle, isOn: $shortcutsEnabled)
            Text(strings.toolShortcutsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 2) {
                ForEach(orderedTools, id: \.self) { tool in
                    toolRow(tool)
                    if tool != orderedTools.last {
                        Divider().padding(.leading, 28)
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else if recordingTool != nil {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: true))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            HStack {
                Spacer()
                Button(l10n.s.shortcutReset) {
                    bindingsRaw = ""
                    errorText = nil
                }
                .disabled(bindingsRaw.isEmpty)
            }
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
        .onAppear {
            keyboard.start()
        }
        .onDisappear { keyboard.stop() }
    }

    private func toolRow(_ tool: ScreenshotSupport.Tool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: tool.screenshotSymbolName)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(tool.screenshotTitle(strings))
                .lineLimit(1)
            Spacer(minLength: 4)

            Group {
                if ScreenshotSupport.Tool.bindings(from: bindingsRaw)[tool] != nil {
                    Button {
                        var bindings = ScreenshotSupport.Tool.bindings(from: bindingsRaw)
                        bindings[tool] = nil
                        bindingsRaw = ScreenshotSupport.Tool.bindingsStorage(bindings)
                        errorText = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 22)
                            .background(Color.primary.opacity(0.045),
                                        in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(l10n.s.shortcutReset)
                    .accessibilityLabel(tool.screenshotTitle(strings) + ": " + l10n.s.shortcutReset)
                } else {
                    Color.clear.frame(width: 20, height: 22)
                }
            }

            shortcutRecorder(for: tool)
                .opacity(shortcutsEnabled ? 1 : 0.48)
        }
        .frame(minHeight: 26)
        .contentShape(Rectangle())
    }

    private func shortcutRecorder(for tool: ScreenshotSupport.Tool) -> some View {
        let binding = ScreenshotSupport.Tool.activeBindings(
            from: bindingsRaw, capsLockOn: keyboard.capsLockOn)[tool]
        // The position digit is a title, not a shortcut: the field shows it
        // as its empty state so nothing else (Delete, reset) treats it as a
        // recorded key.
        let label = ScreenshotSupport.Tool.shortcutLabel(
            for: tool, orderRaw: nil, bindingsRaw: bindingsRaw, enabled: true,
            capsLockOn: keyboard.capsLockOn)
        return ShortcutRecorderButton(
            shortcut: binding ?? .keepAwakeDefault,
            isEnabled: true,
            waitingTitle: l10n.s.shortcutPressKeys,
            requiresModifier: false,
            emptyTitle: binding == nil ? (label ?? l10n.s.shortcutNone) : nil,
            clearAction: { assign(nil, to: tool) },
            notCapturedAction: { errorText = l10n.s.shortcutNotCaptured },
            recordingChanged: { recording in
                recordingTool = recording ? tool : nil
                if recording { errorText = nil }
            },
            captureWithFlagsAction: { shortcut, flags in
                assign(shortcut, to: tool, capsLockOn: flags.contains(.maskAlphaShift))
            },
            invalidAction: { errorText = l10n.s.shortcutNotCaptured },
            captureAction: { assign($0, to: tool, capsLockOn: keyboard.capsLockOn) })
            .frame(width: 86)
            .accessibilityLabel(tool.screenshotTitle(strings))
    }

    private func assign(_ shortcut: GlobalShortcut?, to tool: ScreenshotSupport.Tool,
                        capsLockOn: Bool = false) {
        if let shortcut, let rejection = ScreenshotSupport.Tool.bindingRejection(
            for: shortcut, excluding: tool, bindingsRaw: bindingsRaw,
            roleConflict: { GlobalShortcutRole.conflict(for: $0, excluding: nil) },
            windowLayoutConflict: { WindowLayoutService.shared.shortcutConflictTitle($0) },
            systemConflict: { $0.conflictsWithSystemShortcut }) {
            let reason: String
            switch rejection {
            case .reserved:
                reason = strings.toolShortcutReserved
            case .tool(let other):
                reason = String(format: l10n.s.shortcutConflictFormat, other.screenshotTitle(strings))
            case .role(let role):
                reason = String(format: l10n.s.shortcutConflictFormat, role.title(l10n.s))
            case .windowLayout(let title):
                reason = String(format: l10n.s.shortcutConflictFormat, title)
            case .system:
                reason = String(format: l10n.s.shortcutConflictFormat, "macOS")
            }
            errorText = tool.screenshotTitle(strings) + " · " + shortcut.displayString + "\n" + reason
            return
        }
        var bindings = ScreenshotSupport.Tool.bindings(from: bindingsRaw)
        bindings[tool] = shortcut
        bindingsRaw = ScreenshotSupport.Tool.bindingsStorage(bindings)
        errorText = nil
    }
}

/// Only visible editor/shortcut controls observe keyboard context. Saved
/// preferences stay unchanged; badges reflect which bindings can work now.
final class ScreenshotShortcutContext: ObservableObject {
    @Published private(set) var capsLockOn = false
    private var flagsMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard flagsMonitor == nil else { return }
        updateCapsLock(NSEvent.modifierFlags)
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateCapsLock(event.modifierFlags)
            return event
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: GlobalShortcut.keyboardLayoutDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.objectWillChange.send() })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateCapsLock(NSEvent.modifierFlags) })
    }

    private func updateCapsLock(_ flags: NSEvent.ModifierFlags) {
        let locked = flags.contains(.capsLock)
        if capsLockOn != locked { capsLockOn = locked }
    }

    func stop() {
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        flagsMonitor = nil
        observers.removeAll()
    }

    deinit { stop() }
}
