// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension RadialMenuSettings {
    // MARK: - Switch and triggers

    /// The Dynamic Island page's shape: the feature's switch leads the card,
    /// and what opens the menu unrolls under it, indented.
    var openCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(symbol: AppFeature.radialMenu.symbolName, title: text.enableLabel) {
                    HStack(spacing: 6) {
                        infoButton
                        FeatureActivationControl(feature: .radialMenu)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .accessibilityLabel(text.enableLabel)
                    }
                }
                if featureOn {
                    shortcutRow
                        .padding(.leading, settingsRowTextInset)
                    trackpadRow
                        .padding(.leading, settingsRowTextInset)
                    RadialMouseButtonRow(raw: $mouseButtonRaw, text: text, isEnabled: featureOn)
                        .padding(.leading, settingsRowTextInset)
                }
            }
        }
    }

    private var infoButton: some View {
        Button {
            showsOpenInfo.toggle()
        } label: {
            Image(systemName: "info.circle")
                .frame(width: 24, height: 24)
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
                .frame(width: 260, alignment: .leading)
                .padding(14)
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
        // A refused capture shows in the recorder itself, like every other
        // shortcut field; only a lasting refusal by macOS keeps a mark.
        let status: RadialRowNote.Content? = service.registrationFailed ? .problem(text.shortcutRefused) : nil
        return RadialTriggerRow(title: text.shortcutLabel, help: text.openInfoBody, status: status) {
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
        let status: RadialRowNote.Content? = trackpadGesture != .off && middleClick.touchDeviceMissing
            ? .problem(l10n.s.middleClickNoTrackpad) : nil
        return RadialTriggerRow(title: text.trackpadLabel, help: text.trackpadHelp, status: status) {
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

/// One line of the triggers: the title (its tooltip explains the trigger),
/// a status mark when something is wrong or worth knowing, the control.
/// Momentary errors show inside the control, as in every shortcut field.
struct RadialTriggerRow<Control: View>: View {
    let title: String
    var help: String? = nil
    let status: RadialRowNote.Content?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(help ?? title)
                .layoutPriority(1)
            Spacer(minLength: 12)
            if let status {
                RadialStatusMark(content: status)
            }
            control
        }
    }
}

/// A status as an icon whose tooltip and accessibility label carry the
/// words: a triangle for a problem, a circle for information.
struct RadialStatusMark: View {
    let content: RadialRowNote.Content

    var body: some View {
        let problem: Bool = { if case .problem = content { return true } else { return false } }()
        Image(systemName: problem ? "exclamationmark.triangle.fill" : "info.circle")
            .foregroundStyle(problem ? Color.orange : Color.secondary)
            .help(content.text)
            .accessibilityLabel(content.text)
    }
}

/// A note as an icon and one line of text, for rows that have room for it.
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
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption)
        .help(content.text)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mouse button

/// The menu's one mouse button: a Set… button that listens for the next
/// extra button, and once one is set, its name with a Clear button.
/// Listening shares the Mouse Buttons page's flag, so the two pages never
/// capture at once and the menu's own tap lets the press through.
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
    @State private var errorText: String?
    @State private var nothingSeen = false
    @State private var hovering = false
    @State private var pulse = false
    @State private var shakes: CGFloat = 0
    @State private var monitors: [Any] = []
    @State private var recordingToken = 0
    /// Developer builds only: shows the row as set or unset without saving.
    @State private var previewRaw: String?

    /// How long a recording waits before saying nothing has arrived.
    static let nothingSeenDelay: TimeInterval = 5

    private var trigger: RadialMenuMouseTrigger { RadialMenuMouseTrigger.sanitized(previewRaw ?? raw) }

    var body: some View {
        RadialTriggerRow(title: text.mouseButtonLabel, help: text.openInfoBody, status: status) {
            HStack(spacing: 8) {
                if recording {
                    recordingButton
                } else if let button = trigger.buttonNumber {
                    Text(name(of: button))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Button(text.mouseButtonClearShort) {
                        if previewRaw != nil { previewRaw = RadialMenuMouseTrigger.off.rawValue; return }
                        raw = RadialMenuMouseTrigger.off.rawValue
                        RadialMenuService.shared.syncWithPreferences()
                    }
                    .help(text.mouseButtonClear)
                } else {
                    Button(text.mouseButtonSet) { start() }
                        .help(text.mouseButtonRecording)
                }
#if LATTICE_DEVELOPMENT
                debugToggle
#endif
            }
        }
        .onChange(of: capture.lastInputSeen) { _, seen in handle(seen) }
        .onChange(of: isEnabled) { _, on in if !on { stop() } }
        .onDisappear { stop() }
    }

    private var status: RadialRowNote.Content? {
        guard !recording, let button = trigger.buttonNumber else { return nil }
        if previewRaw == nil, isEnabled, permissions.accessibility, !service.isWatchingMouseButton {
            return .problem(text.mouseButtonBlind)
        }
        if button == MouseButtonShortcutSupport.backButtonNumber { return .info(text.mouseButtonBackNote) }
        if button == MouseButtonShortcutSupport.forwardButtonNumber { return .info(text.mouseButtonForwardNote) }
        return nil
    }

    private func name(of button: Int64) -> String {
        switch button {
        case MouseButtonShortcutSupport.backButtonNumber: return text.mouseTriggerBack
        case MouseButtonShortcutSupport.forwardButtonNumber: return text.mouseTriggerForward
        default:
            return MouseButtonShortcutSupport.buttonName(for: button, strings: FeatureStrings.mouseButtons(l10n.language))
        }
    }

    /// While listening: the prompt, a short error in place when the left or
    /// right button is pressed, or a hint once nothing has arrived.
    private var recordingButton: some View {
        let label = errorText ?? (nothingSeen ? text.mouseButtonNothingSeenShort : text.mouseButtonRecording)
        let tint: Color = errorText != nil ? .red : .accentColor
        return Button {
            showError(text.mouseButtonPrimaryRefusedShort)
        } label: {
            HStack(spacing: 6) {
                if errorText != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                } else {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                        .opacity(pulse ? 0.25 : 1)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(errorText != nil ? Color.red : (nothingSeen ? Color.secondary : Color.accentColor))
            .padding(.horizontal, 10)
            .frame(width: 170, height: 26)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(tint, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(CompactRecorderShakeEffect(animatableData: shakes))
        .onHover { hovering = $0 }
        .help(errorText != nil ? text.mouseButtonPrimaryRefused
                               : (nothingSeen ? text.mouseButtonNothingSeen : text.mouseButtonRecording))
        .accessibilityLabel(text.mouseButtonLabel)
        .accessibilityValue(label)
    }

#if LATTICE_DEVELOPMENT
    /// Cycles the row through set, unset and the real setting, so both
    /// looks can be checked without a mouse that has extra buttons.
    private var debugToggle: some View {
        Button {
            switch previewRaw {
            case nil: previewRaw = RadialMenuMouseTrigger.back.rawValue
            case RadialMenuMouseTrigger.back.rawValue: previewRaw = RadialMenuMouseTrigger.off.rawValue
            default: previewRaw = nil
            }
        } label: {
            Image(systemName: previewRaw == nil ? "ladybug" : "ladybug.fill")
                .foregroundStyle(previewRaw == nil ? Color.secondary : Color.purple)
        }
        .buttonStyle(.plain)
        .help("Debug: preview the mouse button row as set, unset, then real")
    }
#endif

    private func showError(_ message: String) {
        NSSound.beep()
        errorText = message
        withAnimation(.default) { shakes += 1 }
        let shown = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if errorText == shown { errorText = nil }
        }
    }

    private func start() {
        guard isEnabled, !recording else { return }
        errorText = nil
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
        errorText = nil
        nothingSeen = false
        recordingToken &+= 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { pulse = false }
        MouseButtonShortcutService.shared.setCapturing(false)
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    /// Esc cancels; a click elsewhere cancels; the left button over the
    /// recorder, or the right one anywhere, is refused and listening goes on.
    private func installMonitors() {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            guard recording, Int(event.keyCode) == 53 else { return event }
            stop()
            return nil
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in
            guard recording else { return event }
            if event.type == .rightMouseDown || hovering {
                showError(text.mouseButtonPrimaryRefusedShort)
                return nil
            }
            stop()
            return event
        }) { monitors.append(monitor) }
    }

    private func handle(_ seen: Int64?) {
        guard recording, let seen, MouseButtonShortcutSupport.buttonRange.contains(seen) else { return }
        previewRaw = nil
        raw = RadialMenuMouseTrigger.button(seen).rawValue
        stop()
        RadialMenuService.shared.syncWithPreferences()
    }
}
