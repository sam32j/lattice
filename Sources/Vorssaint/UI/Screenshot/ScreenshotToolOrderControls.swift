// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class ToolShortcutCoordinator: ObservableObject {
    static let shared = ToolShortcutCoordinator()
    @Published var activeTool: ScreenshotSupport.Tool?

    func startRecording(tool: ScreenshotSupport.Tool) {
        if activeTool != tool {
            if activeTool != nil {
                ShortcutCapture.end()
            }
            activeTool = tool
            ShortcutCapture.begin()
        }
    }

    func stopRecording(tool: ScreenshotSupport.Tool? = nil) {
        if let tool {
            if activeTool == tool {
                activeTool = nil
                ShortcutCapture.end()
            }
        } else {
            if activeTool != nil {
                activeTool = nil
                ShortcutCapture.end()
            }
        }
    }
}

/// Controls for screenshot annotation tool shortcut assignments.
struct ScreenshotToolOrderControls: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var shortcutsEnabled: Bool
    var showsTitle = true
    @AppStorage(DefaultsKey.screenshotToolShortcuts) private var bindingsRaw = ""
    @State private var errorTool: ScreenshotSupport.Tool?
    @State private var shakeAttempts: [ScreenshotSupport.Tool: CGFloat] = [:]

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var workflow: CaptureWorkflowStrings {
        .localized(l10n.language)
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

            HStack {
                Spacer()
                Button(l10n.s.shortcutReset) {
                    bindingsRaw = ""
                    errorTool = nil
                }
                .disabled(bindingsRaw.isEmpty)
            }
        }
        .onChange(of: l10n.language) { _, _ in errorTool = nil }
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
                if ScreenshotSupport.Tool.isModified(tool: tool, bindingsRaw: bindingsRaw) {
                    Button {
                        resetTool(tool)
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

            ToolShortcutRecorder(
                tool: tool,
                isEnabled: shortcutsEnabled,
                bindingsRaw: $bindingsRaw,
                isError: errorTool == tool,
                shakeAttempts: shakeAttempts[tool, default: 0],
                onError: {
                    showError(for: tool)
                }
            )
            .opacity(shortcutsEnabled ? 1 : 0.48)
        }
        .frame(minHeight: 26)
        .contentShape(Rectangle())
    }

    private func resetTool(_ tool: ScreenshotSupport.Tool) {
        if let defaultShortcut = tool.defaultShortcut {
            let currentShortcuts = ScreenshotSupport.Tool.effectiveShortcuts(from: bindingsRaw)
            if currentShortcuts.contains(where: { $0.key != tool && $0.value == defaultShortcut }) {
                showError(for: tool)
                return
            }
        }
        var custom = ScreenshotSupport.Tool.customBindings(from: bindingsRaw)
        custom[tool] = nil
        bindingsRaw = ScreenshotSupport.Tool.customBindingsStorage(custom)
        if errorTool == tool {
            errorTool = nil
        }
    }

    private func showError(for tool: ScreenshotSupport.Tool) {
        errorTool = tool
        NSSound.beep()
        withAnimation(.default) {
            shakeAttempts[tool, default: 0] += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.errorTool == tool {
                self.errorTool = nil
            }
        }
    }
}

private struct ToolShortcutRecorder: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var coordinator = ToolShortcutCoordinator.shared
    let tool: ScreenshotSupport.Tool
    let isEnabled: Bool
    @Binding var bindingsRaw: String
    let isError: Bool
    let shakeAttempts: CGFloat
    let onError: () -> Void

    @State private var isHovering = false

    private var isRecording: Bool { coordinator.activeTool == tool }

    private var currentShortcut: GlobalShortcut? {
        ScreenshotSupport.Tool.effectiveShortcut(for: tool, bindingsRaw: bindingsRaw)
    }

    private var workflow: CaptureWorkflowStrings {
        .localized(l10n.language)
    }

    private let recorderWidth: CGFloat = 86
    private let recorderHeight: CGFloat = 26

    var body: some View {
        ZStack {
            Button {
                if !isEnabled { return }
                if isRecording {
                    coordinator.stopRecording(tool: tool)
                } else {
                    coordinator.startRecording(tool: tool)
                }
            } label: {
                HStack(spacing: 3) {
                    if isError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.red)
                        Text(workflow.shortcutUnavailable)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    } else if isRecording {
                        Text(l10n.s.shortcutPressKeys)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else if let currentShortcut {
                        Text(currentShortcut.displayString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text(l10n.s.shortcutNone)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: recorderWidth, height: recorderHeight)
        .modifier(CompactRecorderShakeEffect(animatableData: shakeAttempts))
        .background(
            backgroundColor,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    borderColor,
                    lineWidth: (isRecording || isError) ? 1.5 : (isHovering ? 0.8 : 0.5)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onDisappear {
            coordinator.stopRecording(tool: tool)
        }
        .background {
            if isRecording {
                KeyCaptureBridgeView(
                    onKeyDown: { event in
                        handleKeyEvent(event)
                    },
                    onFlagsChanged: { _ in }
                )
            }
        }
    }

    private var backgroundColor: Color {
        if isError {
            return Color.red.opacity(0.12)
        } else if isRecording {
            return Color.accentColor.opacity(0.12)
        } else if isHovering {
            return Color.primary.opacity(0.06)
        } else {
            return Color.primary.opacity(0.03)
        }
    }

    private var borderColor: Color {
        if isError {
            return Color.red
        } else if isRecording {
            return Color.accentColor
        } else if isHovering {
            return Color.primary.opacity(0.25)
        } else {
            return Color.primary.opacity(0.12)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            coordinator.stopRecording(tool: tool)
            return
        }
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        if GlobalShortcut.clearsShortcut(keyCode: Int64(event.keyCode), modifiers: modifiers) {
            clearShortcut()
            coordinator.stopRecording(tool: tool)
            return
        }
        let captured = GlobalShortcut(keyCode: Int64(event.keyCode), modifiers: modifiers)
        if let _ = ScreenshotSupport.Tool.bindingRejection(
            for: captured, excluding: tool, bindingsRaw: bindingsRaw,
            roleConflict: { GlobalShortcutRole.conflict(for: $0, excluding: nil) },
            windowLayoutConflict: { WindowLayoutService.shared.shortcutConflictTitle($0) },
            systemConflict: { $0.conflictsWithSystemShortcut }) {
            onError()
            return
        }
        var custom = ScreenshotSupport.Tool.customBindings(from: bindingsRaw)
        custom[tool] = .some(captured)
        bindingsRaw = ScreenshotSupport.Tool.customBindingsStorage(custom)
        coordinator.stopRecording(tool: tool)
    }

    private func clearShortcut() {
        var custom = ScreenshotSupport.Tool.customBindings(from: bindingsRaw)
        if tool.defaultShortcut != nil {
            custom[tool] = .some(nil)
        } else {
            custom[tool] = nil
        }
        bindingsRaw = ScreenshotSupport.Tool.customBindingsStorage(custom)
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
