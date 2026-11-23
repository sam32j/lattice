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
                    FeatureActivationControl(feature: .radialMenu)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(text.enableLabel)
                }
                if featureOn {
                    shortcutRow
                        .padding(.leading, settingsRowTextInset)
                    trackpadRow
                        .padding(.leading, settingsRowTextInset)
                    RadialMouseButtonRow(raw: $mouseButtonRaw, previewRaw: $mouseButtonPreview,
                                         text: text, isEnabled: featureOn)
                        .padding(.leading, settingsRowTextInset)
                }
            }
        }
    }

#if LATTICE_DEVELOPMENT
    /// Developer builds only, outside the card: cycles the mouse button row
    /// through set, unset and the real setting without saving anything.
    var mouseButtonDebugToggle: some View {
        HStack {
            Spacer()
            Button {
                switch mouseButtonPreview {
                case nil: mouseButtonPreview = RadialMenuMouseTrigger.back.rawValue
                case RadialMenuMouseTrigger.back.rawValue: mouseButtonPreview = RadialMenuMouseTrigger.off.rawValue
                default: mouseButtonPreview = nil
                }
            } label: {
                Label(mouseButtonPreview == nil ? "Preview mouse button: real"
                      : (mouseButtonPreview == RadialMenuMouseTrigger.off.rawValue
                         ? "Preview mouse button: unset" : "Preview mouse button: set"),
                      systemImage: mouseButtonPreview == nil ? "ladybug" : "ladybug.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(mouseButtonPreview == nil ? Color.secondary : Color.purple)
        }
    }
#endif

    // MARK: - Keyboard shortcut

    var savedShortcut: GlobalShortcut? {
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.radialMenuShortcut, fallback: .radialMenuDefault)
        return shortcut.isValid ? shortcut : nil
    }

    private var shortcutRow: some View {
        // Reading the stored value keeps the row in step with the central
        // Shortcuts page, which writes the same key.
        let _ = shortcutRaw
        // A refused combination is explained in the conflict dialog the
        // other shortcut rows use, never in red inside the field; only a
        // lasting refusal by macOS keeps a mark.
        let status: RadialRowNote.Content? = service.registrationFailed ? .problem(text.shortcutRefused) : nil
        return RadialTriggerRow(title: text.shortcutLabel, status: status) {
            CompactShortcutBindingRecorder(
                recordingID: "radial-menu-shortcut",
                shortcut: savedShortcut,
                isEnabled: featureOn,
                width: 140,
                emptyTitle: l10n.s.shortcutNone,
                canClear: savedShortcut != nil,
                errorText: $invalidShortcutMessage,
                onClear: { saveShortcut("") },
                onReset: {},
                onCapture: { newShortcut in
                    if let owner = shortcutConflictTitle(newShortcut) {
                        conflictAlert = ShortcutConflictAlert(shortcut: newShortcut, assignedBehavior: owner)
                        return
                    }
                    saveShortcut(newShortcut.storageValue)
                })
        }
        .shortcutConflictAlert($conflictAlert)
    }

    /// Who already answers to a combination: another Lattice shortcut, a
    /// window layout, a Command Bar row, or macOS itself.
    func shortcutConflictTitle(_ shortcut: GlobalShortcut) -> String? {
        if let role = GlobalShortcutRole.conflict(for: shortcut, excluding: .radialMenu) {
            return role.title(l10n.s)
        }
        if let title = SettingsShortcutConflicts.title(for: shortcut, language: l10n.language) {
            return title
        }
        return shortcut.conflictsWithSystemShortcut(for: .radialMenu) ? "macOS" : nil
    }

    func saveShortcut(_ storageValue: String) {
        shortcutRaw = storageValue
        FeatureRuntime.shared.sync([.radialMenu])
    }

    // MARK: - Trackpad

    private var trackpadRow: some View {
        let status: RadialRowNote.Content? = trackpadGesture != .off && middleClick.touchDeviceMissing
            ? .problem(l10n.s.middleClickNoTrackpad) : nil
        return RadialTriggerRow(title: text.trackpadLabel, status: status) {
            SettingsPopUpPicker(title: text.trackpadLabel, options: [
                .init(value: RadialMenuTrackpadGesture.off, title: text.trackpadOff),
                .init(value: RadialMenuTrackpadGesture.tap, title: text.trackpadTap),
                .init(value: RadialMenuTrackpadGesture.click, title: text.trackpadClick),
            ], selection: Binding(get: { trackpadGesture }, set: requestTrackpadGesture),
               exactWidth: RadialTriggerRow<EmptyView>.controlWidth)
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

    /// The one width every trigger control shares.
    static var controlWidth: CGFloat { 140 }

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
    /// Developer builds only: shows the row as set or unset without saving.
    @Binding var previewRaw: String?
    let text: RadialMenuFeatureStrings
    let isEnabled: Bool

    @ObservedObject private var capture = MouseButtonShortcutService.shared
    @ObservedObject private var service = RadialMenuService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recording = false
    @State private var nothingSeen = false
    @State private var hovering = false
    @State private var clearHovering = false
    @State private var pulse = false
    @State private var shakes: CGFloat = 0
    @State private var monitors: [Any] = []
    @State private var recordingToken = 0
    /// Developer builds only: shows the row as set or unset without saving.

    /// How long a recording waits before saying nothing has arrived.
    static let nothingSeenDelay: TimeInterval = 5

    private var trigger: RadialMenuMouseTrigger { RadialMenuMouseTrigger.sanitized(previewRaw ?? raw) }

    var body: some View {
        RadialTriggerRow(title: text.mouseButtonLabel, status: status) {
            HStack(spacing: 8) {
                if recording {
                    recordingButton
                } else if let button = trigger.buttonNumber {
                    // Set: a green Active state (its tooltip names the button)
                    // and Clear, at their natural width.
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text(text.mouseButtonActive)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .help(activeHelp(button))
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(activeHelp(button))
                        Button {
                            if previewRaw != nil { previewRaw = RadialMenuMouseTrigger.off.rawValue; return }
                            raw = RadialMenuMouseTrigger.off.rawValue
                            RadialMenuService.shared.syncWithPreferences()
                        } label: {
                            Text(text.mouseButtonClearShort)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(height: 26)
                                .background(Color.primary.opacity(clearHovering ? 0.06 : 0.03),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.primary.opacity(clearHovering ? 0.25 : 0.12),
                                            lineWidth: clearHovering ? 0.8 : 0.5))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { clearHovering = $0 }
                        .help(text.mouseButtonClear)
                    }
                } else {
                    Button { start() } label: {
                        Text(text.mouseButtonSet)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .frame(width: RadialTriggerRow<EmptyView>.controlWidth, height: 26)
                            .background(Color.primary.opacity(hovering ? 0.06 : 0.03),
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(hovering ? 0.25 : 0.12), lineWidth: hovering ? 0.8 : 0.5))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering = $0 }
                    .help(text.mouseButtonRecording)
                }
            }
            // Every state (Set button…, listening, Active with Clear) sits in the
            // same height as the shortcut field, so the row never shifts.
            .frame(height: 26)
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
        _ = button
        return nil
    }

    /// The Active tooltip: the button's name, and for the back and forward
    /// buttons what they stop doing in apps.
    private func activeHelp(_ button: Int64) -> String {
        switch button {
        case MouseButtonShortcutSupport.backButtonNumber: return "\(name(of: button))\n\(text.mouseButtonBackNote)"
        case MouseButtonShortcutSupport.forwardButtonNumber: return "\(name(of: button))\n\(text.mouseButtonForwardNote)"
        default: return name(of: button)
        }
    }

    private func name(of button: Int64) -> String {
        switch button {
        case MouseButtonShortcutSupport.backButtonNumber: return text.mouseTriggerBack
        case MouseButtonShortcutSupport.forwardButtonNumber: return text.mouseTriggerForward
        default:
            return MouseButtonShortcutSupport.buttonName(for: button, strings: FeatureStrings.mouseButtons(l10n.language))
        }
    }

    /// While listening: the prompt, or a hint once nothing has arrived. A
    /// left or right click is refused with a beep and a shake, never with
    /// red text; the tooltip says why.
    private var recordingButton: some View {
        let label = nothingSeen ? text.mouseButtonNothingSeenShort : text.mouseButtonRecording
        return Button {
            refuse()
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                    .opacity(pulse ? 0.25 : 1)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(nothingSeen ? Color.secondary : Color.accentColor)
            .padding(.horizontal, 8)
            .frame(width: RadialTriggerRow<EmptyView>.controlWidth, height: 26)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(CompactRecorderShakeEffect(animatableData: shakes))
        .onHover { hovering = $0 }
        .help(nothingSeen ? text.mouseButtonNothingSeen : text.mouseButtonPrimaryRefused)
        .accessibilityLabel(text.mouseButtonLabel)
        .accessibilityValue(label)
    }


    private func refuse() {
        NSSound.beep()
        withAnimation(.default) { shakes += 1 }
    }

    private func start() {
        guard isEnabled, !recording else { return }
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
                refuse()
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
