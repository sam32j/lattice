// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension RadialMenuSettings {
    // MARK: - Open the menu

    var openCard: some View {
        SettingsCard(symbol: "cursorarrow.rays", title: text.openCardTitle, headerAccessory: {
            Button {
                showsOpenInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(text.openInfoButton)
            .accessibilityLabel(text.openInfoButton)
            .popover(isPresented: $showsOpenInfo, arrowEdge: .bottom) {
                Text(text.openInfoBody)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(14)
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                shortcutRow
                Divider()
                trackpadRow
                Divider()
                RadialMouseButtonRow(raw: $mouseButtonRaw, text: text, isEnabled: featureOn)
            }
            .disabled(!featureOn)
            .saturation(featureOn ? 1 : 0)
            .opacity(featureOn ? 1 : 0.45)
        }
    }

    // MARK: - Keyboard shortcut

    var savedShortcut: GlobalShortcut? {
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.radialMenuShortcut, fallback: .radialMenuDefault)
        return shortcut.isValid ? shortcut : nil
    }

    private var shortcutRow: some View {
        // Reading the stored value keeps the row in step with the central
        // Shortcuts page, which writes the same key.
        let _ = shortcutRaw
        let note: RadialRowNote.Content? = shortcutError.map { .problem($0) }
            ?? (featureOn && service.registrationFailed ? .problem(text.shortcutRefused) : nil)
        return RadialTriggerRow(title: text.shortcutLabel, note: note) {
            CompactShortcutBindingRecorder(
                recordingID: "radial-menu-shortcut",
                shortcut: savedShortcut,
                isEnabled: featureOn,
                width: 140,
                emptyTitle: l10n.s.shortcutNone,
                canClear: savedShortcut != nil,
                errorText: $shortcutError,
                onClear: {
                    shortcutError = nil
                    saveShortcut("")
                },
                onReset: {},
                onCapture: { newShortcut in
                    if let owner = shortcutConflictTitle(newShortcut) {
                        shortcutError = String(format: l10n.s.shortcutConflictFormat, owner)
                        return
                    }
                    shortcutError = nil
                    saveShortcut(newShortcut.storageValue)
                })
        }
    }

    /// Who already answers to a combination: another Lattice shortcut, a
    /// window layout or a Command Bar row. There are no other wheels to ask.
    func shortcutConflictTitle(_ shortcut: GlobalShortcut) -> String? {
        if let role = GlobalShortcutRole.conflict(for: shortcut, excluding: .radialMenu) {
            return role.title(l10n.s)
        }
        return SettingsShortcutConflicts.title(for: shortcut, language: l10n.language)
    }

    func saveShortcut(_ storageValue: String) {
        shortcutRaw = storageValue
        FeatureRuntime.shared.sync([.radialMenu])
    }

    // MARK: - Trackpad

    private var trackpadRow: some View {
        let note: RadialRowNote.Content? = trackpadGesture != .off && middleClick.touchDeviceMissing
            ? .problem(l10n.s.middleClickNoTrackpad) : nil
        return RadialTriggerRow(title: text.trackpadLabel, note: note) {
            SettingsPopUpPicker(title: text.trackpadLabel, options: [
                .init(value: RadialMenuTrackpadGesture.off, title: text.trackpadOff),
                .init(value: RadialMenuTrackpadGesture.tap, title: text.trackpadTap),
                .init(value: RadialMenuTrackpadGesture.click, title: text.trackpadClick),
            ], selection: Binding(get: { trackpadGesture }, set: requestTrackpadGesture))
            .fixedSize()
            .help(trackpadTitle(trackpadGesture))
        }
    }

    private func trackpadTitle(_ gesture: RadialMenuTrackpadGesture) -> String {
        switch gesture {
        case .off: return text.trackpadOff
        case .tap: return text.trackpadTap
        case .click: return text.trackpadClick
        }
    }

    /// Choosing a gesture Middle Click is using right now asks first;
    /// anything else applies (asking for Accessibility when it is needed).
    func requestTrackpadGesture(_ gesture: RadialMenuTrackpadGesture) {
        guard gesture != trackpadGesture else { return }
        if takeoverNeeded(for: gesture) {
            pendingTakeover = gesture
        } else {
            applyTrackpadGesture(gesture)
        }
    }

    /// Whether Middle Click is on and really answering this four-finger
    /// gesture now, so taking it would change a working setup.
    func takeoverNeeded(for gesture: RadialMenuTrackpadGesture) -> Bool {
        guard gesture != .off, AppFeature.middleClick.isAvailable, middleClickEnabled else { return false }
        let current = featureOn ? trackpadGesture : .off
        switch gesture {
        case .tap:
            return MiddleClickSupport.effectiveTapFingers(
                stored: Defaults.sanitizedMiddleClickTapFingers(middleClickTapFingers),
                systemOwnsThreeFingerTap: middleClick.systemOwnsThreeFingerTap,
                radialGesture: current) == 4
        case .click:
            return MiddleClickSupport.effectiveClickFingers(
                stored: Defaults.sanitizedMiddleClickClickFingers(middleClickClickFingers),
                systemDragEnabled: middleClick.systemDragGestureConflict,
                radialGesture: current) == 4
        case .off:
            return false
        }
    }

    func applyTrackpadGesture(_ gesture: RadialMenuTrackpadGesture) {
        gestureCoordinator?.cancel()
        let next = PermissionActivationCoordinator(
            requirements: gesture == .off ? [] : [.accessibility],
            verify: permissionAccess.verify,
            requestAccess: permissionAccess.request,
            applyEnabled: { granted in
                guard granted else { return }
                trackpadGestureRaw = gesture.rawValue
                RadialMenuService.shared.syncWithPreferences()
            })
        gestureCoordinator = next
        next.setEnabled(true)
    }
}

// MARK: - Rows and notes

/// One line of the Open the menu card: title, an optional one-line note
/// under it, the control on the right.
struct RadialTriggerRow<Control: View>: View {
    let title: String
    let note: RadialRowNote.Content?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let note {
                    RadialRowNote(content: note)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            control
        }
    }
}

/// A row's note: an icon and a line of text, never color alone. Problems
/// are orange triangles; information is a secondary circle.
struct RadialRowNote: View {
    enum Content: Equatable {
        case problem(String)
        case info(String)

        var text: String {
            switch self {
            case .problem(let text), .info(let text): return text
            }
        }
    }

    let content: Content

    var body: some View {
        let problem: Bool = { if case .problem = content { return true } else { return false } }()
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: problem ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundStyle(problem ? Color.orange : Color.secondary)
                .accessibilityHidden(true)
            Text(content.text)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .font(.caption)
        .help(content.text)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mouse button

/// The menu's one mouse button, set by pressing it. Recording shares the
/// Mouse Buttons page's listening flag, so the two pages never capture at
/// once and the menu's own tap lets the press through while it listens.
struct RadialMouseButtonRow: View {
    @Binding var raw: String
    let text: RadialMenuFeatureStrings
    let isEnabled: Bool

    @ObservedObject private var capture = MouseButtonShortcutService.shared
    @ObservedObject private var service = RadialMenuService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recording = false
    @State private var refusedPrimary = false
    @State private var nothingSeen = false
    @State private var hovering = false
    @State private var pulse = false
    @State private var monitors: [Any] = []
    @State private var recordingToken = 0

    /// How long a recording waits before saying nothing has arrived.
    static let nothingSeenDelay: TimeInterval = 5

    private var trigger: RadialMenuMouseTrigger { RadialMenuMouseTrigger.sanitized(raw) }

    var body: some View {
        RadialTriggerRow(title: text.mouseButtonLabel, note: note) {
            HStack(spacing: 4) {
                recorderButton
                if trigger != .off, !recording {
                    Button {
                        raw = RadialMenuMouseTrigger.off.rawValue
                        RadialMenuService.shared.syncWithPreferences()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(text.mouseButtonClear)
                    .accessibilityLabel(text.mouseButtonClear)
                }
            }
        }
        .onChange(of: capture.lastInputSeen) { _, seen in handle(seen) }
        .onChange(of: isEnabled) { _, on in if !on { stop() } }
        .onDisappear { stop() }
    }

    private var note: RadialRowNote.Content? {
        if recording {
            if refusedPrimary { return .problem(text.mouseButtonPrimaryRefused) }
            if nothingSeen { return .info(text.mouseButtonNothingSeen) }
            return nil
        }
        guard let button = trigger.buttonNumber else { return nil }
        if isEnabled, permissions.accessibility, !service.isWatchingMouseButton {
            return .problem(text.mouseButtonBlind)
        }
        if button == MouseButtonShortcutSupport.backButtonNumber { return .info(text.mouseButtonBackNote) }
        if button == MouseButtonShortcutSupport.forwardButtonNumber { return .info(text.mouseButtonForwardNote) }
        return nil
    }

    private var title: String {
        if recording { return text.mouseButtonRecording }
        guard let button = trigger.buttonNumber else { return l10n.s.shortcutNone }
        switch button {
        case MouseButtonShortcutSupport.backButtonNumber: return text.mouseTriggerBack
        case MouseButtonShortcutSupport.forwardButtonNumber: return text.mouseTriggerForward
        default:
            return MouseButtonShortcutSupport.buttonName(for: button, strings: FeatureStrings.mouseButtons(l10n.language))
        }
    }

    private var recorderButton: some View {
        Button {
            if recording { refusedPrimary = true } else { start() }
        } label: {
            HStack(spacing: 6) {
                if recording {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .opacity(pulse ? 0.25 : 1)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 116)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(recording ? Color.accentColor : Color.primary.opacity(0.15),
                              lineWidth: recording ? 1.5 : 0.8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 140, alignment: .trailing)
        .onHover { hovering = $0 }
        .help(title)
        .accessibilityLabel(text.mouseButtonLabel)
        .accessibilityValue(title)
    }

    private func start() {
        guard isEnabled, !recording else { return }
        refusedPrimary = false
        nothingSeen = false
        recording = true
        recordingToken &+= 1
        let token = recordingToken
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
        }
        MouseButtonShortcutService.shared.setCapturing(true)
        if !permissions.accessibility { permissions.requestAccessibility() }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.nothingSeenDelay) {
            if recording, recordingToken == token { nothingSeen = true }
        }
        installMonitors()
    }

    private func stop() {
        guard recording else { return }
        recording = false
        refusedPrimary = false
        nothingSeen = false
        recordingToken &+= 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { pulse = false }
        MouseButtonShortcutService.shared.setCapturing(false)
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    /// Esc cancels; a click elsewhere cancels; the left or right button
    /// over the recorder (or the right one anywhere) is refused and the
    /// recording goes on.
    private func installMonitors() {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            guard recording, Int(event.keyCode) == 53 else { return event }
            stop()
            return nil
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in
            guard recording else { return event }
            if event.type == .rightMouseDown || hovering {
                refusedPrimary = true
                return nil
            }
            stop()
            return event
        }) { monitors.append(monitor) }
    }

    private func handle(_ seen: Int64?) {
        guard recording, let seen, MouseButtonShortcutSupport.buttonRange.contains(seen) else { return }
        raw = RadialMenuMouseTrigger.button(seen).rawValue
        stop()
        RadialMenuService.shared.syncWithPreferences()
    }
}
