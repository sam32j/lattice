// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

typealias ToolShortcutCoordinator = CompactShortcutCoordinator

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

            ToolShortcutRecorder(
                tool: tool,
                shortcutsEnabled: $shortcutsEnabled,
                bindingsRaw: $bindingsRaw,
                isError: errorTool == tool,
                shakeAttempts: shakeAttempts[tool, default: 0],
                onReset: { resetTool(tool) },
                onError: {
                    showError(for: tool)
                }
            )
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
        shortcutsEnabled = true
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
    @Binding var shortcutsEnabled: Bool
    @Binding var bindingsRaw: String
    let isError: Bool
    let shakeAttempts: CGFloat
    let onReset: () -> Void
    let onError: () -> Void

    private var isRecording: Bool { coordinator.activeTool == tool }

    private var currentShortcut: GlobalShortcut? {
        shortcutsEnabled ? ScreenshotSupport.Tool.effectiveShortcut(for: tool, bindingsRaw: bindingsRaw) : nil
    }

    private var workflow: CaptureWorkflowStrings {
        .localized(l10n.language)
    }

    private let recorderWidth: CGFloat = 140
    var body: some View {
        CompactShortcutField(
            shortcut: currentShortcut,
            isEnabled: true,
            isRecording: isRecording,
            pressedModifiers: [],
            errorText: isError ? workflow.shortcutUnavailable : nil,
            emptyTitle: l10n.s.shortcutNone,
            width: recorderWidth,
            shakeAttempts: shakeAttempts,
            onToggleRecording: toggleRecording,
            onClear: currentShortcut != nil ? clearShortcut : nil,
            onReset: onReset)
        .onDisappear {
            coordinator.stopRecording(tool: tool)
        }
        .background {
            if isRecording {
                KeyCaptureBridgeView(
                    onKeyDown: { event in
                        handleKeyEvent(event)
                    },
                    onFlagsChanged: { _ in },
                    onExit: {
                        coordinator.stopRecording(tool: tool)
                    }
                )
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            coordinator.stopRecording(tool: tool)
        } else {
            coordinator.startRecording(tool: tool)
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
        shortcutsEnabled = true
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
