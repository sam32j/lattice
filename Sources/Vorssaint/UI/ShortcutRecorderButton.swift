// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderButton: NSViewRepresentable {
    let shortcut: GlobalShortcut
    let isEnabled: Bool
    /// Shown inside the field while it is listening. Short on purpose: the
    /// sentence explaining what to do lives in the caption under the row, so
    /// the field never has to grow to fit it.
    let waitingTitle: String
    var requiresModifier = true
    /// When set, the button shows this instead of the shortcut, meaning "no
    /// shortcut assigned"; clicking still records a new one.
    var emptyTitle: String? = nil
    /// Set by rows whose shortcut may be removed. Delete on its own then takes
    /// the shortcut off instead of trying to record.
    var clearAction: (() -> Void)? = nil
    /// Fired when the combination never reached us, so the row can say why.
    var notCapturedAction: (() -> Void)? = nil
    /// Lets the row show its caption exactly while the field is listening.
    var recordingChanged: ((Bool) -> Void)? = nil
    /// For local shortcuts whose typed character also depends on Caps Lock.
    /// When supplied, this handles capture instead of the ordinary callback.
    var captureWithFlagsAction: ((GlobalShortcut, CGEventFlags) -> Void)? = nil
    /// Only hold-trigger fields opt into recording a chord without a key.
    var captureModifiersAction: ((GlobalShortcutModifiers) -> Void)? = nil
    let invalidAction: () -> Void
    let captureAction: (GlobalShortcut) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        // One font in every state. The field used to swap a monospaced cap for
        // a proportional sentence, which changed its width mid-interaction.
        button.font = .systemFont(ofSize: 13, weight: .medium)
        // A translation longer than the field trims instead of spilling over
        // the label beside it.
        button.cell?.lineBreakMode = .byTruncatingTail
        button.target = button
        button.action = #selector(RecorderButton.beginRecording)
        apply(to: button)
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        apply(to: nsView)
    }

    /// The SwiftUI frame decides the width, never the title. An AppKit view's
    /// intrinsic size otherwise wins over the frame, so the field grew with
    /// its own text and slid over the column beside it (issue #308). The
    /// height is the bezel's own, so the control is never drawn short.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: RecorderButton,
                      context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        return CGSize(width: proposal.width ?? intrinsic.width, height: intrinsic.height)
    }

    static func dismantleNSView(_ nsView: RecorderButton, coordinator: ()) {
        // The view can go away mid-recording (a sheet closing, a page swap).
        // Nothing else would give the app's own shortcuts back. The row is
        // going away with it, so drop the callback first rather than touch its
        // state while SwiftUI is taking it apart.
        nsView.recordingChanged = nil
        nsView.stopRecording()
    }

    private func apply(to button: RecorderButton) {
        button.requiresModifier = requiresModifier
        button.shortcut = shortcut
        button.waitingTitle = waitingTitle
        button.emptyTitle = emptyTitle
        button.clearAction = clearAction
        button.notCapturedAction = notCapturedAction
        button.recordingChanged = recordingChanged
        button.captureWithFlagsAction = captureWithFlagsAction
        button.captureModifiersAction = captureModifiersAction
        button.invalidAction = invalidAction
        button.captureAction = captureAction
        button.isEnabled = isEnabled
        button.refreshTitle()
    }
}

final class RecorderButton: NSButton {
    var requiresModifier = true
    var shortcut = GlobalShortcut.keepAwakeDefault
    var waitingTitle = ""
    var emptyTitle: String?
    var clearAction: (() -> Void)?
    var notCapturedAction: (() -> Void)?
    var recordingChanged: ((Bool) -> Void)?
    var captureWithFlagsAction: ((GlobalShortcut, CGEventFlags) -> Void)?
    var captureModifiersAction: ((GlobalShortcutModifiers) -> Void)?
    private var modifierRecording = ModifierShortcutRecording()
    var invalidAction: (() -> Void)?
    var captureAction: ((GlobalShortcut) -> Void)?
    private var isRecording = false
    /// True once a Control, Option or Command combination went down while the
    /// field was listening and no key has arrived since. If the modifiers then
    /// come all the way back up with nothing in between, the key never reached
    /// us: something upstream consumed it.
    private var awaitingKeyForHeldModifiers = false
    private var observers: [NSObjectProtocol] = []

    override var acceptsFirstResponder: Bool { true }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        guard isRecording else { return }
        // Last resort. Leaving the app's shortcuts suspended, or the
        // recording tap eating the keyboard, would be worse than the bug
        // this fixes, so give both back even from here.
        if Thread.isMainThread {
            ShortcutRecordingTap.end()
            ShortcutCapture.end()
        } else {
            DispatchQueue.main.async {
                ShortcutRecordingTap.end()
                ShortcutCapture.end()
            }
        }
    }

    @objc func beginRecording() {
        guard isEnabled, !isRecording else { return }
        // Take the keyboard first: a field that believes it is listening while
        // some other view holds the keys would suspend the app's shortcuts and
        // never see the press that gives them back.
        if window?.firstResponder !== self {
            guard window?.makeFirstResponder(self) == true else { return }
        }
        isRecording = true
        awaitingKeyForHeldModifiers = false
        modifierRecording = ModifierShortcutRecording()
        ShortcutCapture.begin()
        // The tap keeps the typed combination to the field: without it, a
        // combination the system or another app answers to performs that
        // action while being recorded. When the tap cannot exist (no
        // Accessibility), the view events below still record as before.
        ShortcutRecordingTap.begin { [weak self] keyCode, modifiers, flags in
            guard let self, self.isRecording else { return }
            self.handleRecordingKey(keyCode: keyCode, modifiers: modifiers, flags: flags)
        }
        observeExits()
        refreshTitle()
        recordingChanged?(true)
    }

    /// Every route out of recording lands here, and it is safe to call when
    /// nothing is being recorded.
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        awaitingKeyForHeldModifiers = false
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        ShortcutRecordingTap.end()
        ShortcutCapture.end()
        refreshTitle()
        recordingChanged?(false)
    }

    /// Combinations built with Control, Option or Command are offered to the
    /// view hierarchy before the app's own menu, so this is where nearly every
    /// recordable press arrives. Without it the menu answered first and the
    /// app closed its window on Command W or quit on Command Q instead of
    /// recording them (issue #308).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        handleRecordingKey(event)
        return true
    }

    /// Keys with no Control, Option or Command never reach the key equivalent
    /// path, so Escape, Delete and plain keys land here.
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handleRecordingKey(event)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        if let captureModifiersAction {
            let unsupported = event.modifierFlags.contains(.function)
            let captured = modifierRecording.flagsChanged(modifiers, hasUnsupportedModifier: unsupported)
            if unsupported {
                invalidAction?()
                return
            }
            if let captured {
                guard captured.isValidWindowDirectionalTrigger else {
                    invalidAction?()
                    return
                }
                stopRecording()
                captureModifiersAction(captured)
            }
            return
        }
        if modifiers.hasPrimaryModifier {
            awaitingKeyForHeldModifiers = true
        } else if modifiers.isEmpty, awaitingKeyForHeldModifiers {
            awaitingKeyForHeldModifiers = false
            notCapturedAction?()
        }
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopRecording() }
    }

    private func handleRecordingKey(_ event: NSEvent) {
        handleRecordingKey(keyCode: Int64(event.keyCode),
                           modifiers: GlobalShortcutModifiers(eventFlags: event.modifierFlags),
                           flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
    }

    /// The one recording path, fed by the swallowing tap or, without it, by
    /// the view events above.
    private func handleRecordingKey(keyCode: Int64, modifiers: GlobalShortcutModifiers,
                                    flags: CGEventFlags) {
        // A key arrived, so the modifiers being held did produce something.
        awaitingKeyForHeldModifiers = false
        modifierRecording.keyPressed()

        if keyCode == Int64(kVK_Escape), !modifiers.hasPrimaryModifier {
            stopRecording()
            return
        }
        if GlobalShortcut.clearsShortcut(keyCode: keyCode, modifiers: modifiers) {
            guard let clearAction else { return }
            stopRecording()
            clearAction()
            return
        }
        let captured = GlobalShortcut(keyCode: keyCode, modifiers: modifiers)
        // Fn on a letter cannot be represented by the saved shortcut. Do not
        // silently record N when the user pressed Fn-N. Function/navigation
        // keys carry this flag intrinsically and remain recordable.
        if !requiresModifier, flags.contains(.maskSecondaryFn),
           !captured.syntheticEventFlags.contains(.maskSecondaryFn) {
            invalidAction?()
            return
        }
        guard requiresModifier ? captured.isValid : captured.hasPrintableKey else {
            NSSound.beep()
            invalidAction?()
            return
        }
        shortcut = captured
        stopRecording()
        if let captureWithFlagsAction {
            captureWithFlagsAction(captured, flags)
        } else {
            captureAction?(captured)
        }
    }

    /// Watchers that exist only while the field is listening. Each one is a
    /// way out of recording that no key press would announce.
    private func observeExits() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.stopRecording()
        })
        if let window {
            observers.append(center.addObserver(forName: NSWindow.willCloseNotification,
                                                object: window, queue: .main) { [weak self] _ in
                self?.stopRecording()
            })
        }
    }

    func refreshTitle() {
        if isRecording {
            title = waitingTitle
        } else {
            title = emptyTitle ?? shortcut.displayString
        }
    }
}

struct ShortcutPreferenceRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var superKey = SuperKeyService.shared

    private let role: GlobalShortcutRole
    private let isEnabled: Bool
    private let label: String?
    private let symbolName: String?
    private let contextLabel: String?
    private let statusText: String?
    private let statusIsActive: Bool
    private let showsSuperKeyAlternative: Bool
    private let superKeyModifiers: GlobalShortcutModifiers
    private let includeInactiveConflicts: Bool
    private let reservesClearButtonSpace: Bool
    private let onChange: () -> Void
    private let additionalConflict: (GlobalShortcut) -> String?
    @AppStorage private var rawValue: String
    @State private var errorText: String?
    @State private var isRecording = false
    @State private var pendingTakeOver: GlobalShortcut?

    init(role: GlobalShortcutRole,
         isEnabled: Bool = true,
         label: String? = nil,
         symbolName: String? = nil,
         contextLabel: String? = nil,
         statusText: String? = nil,
         statusIsActive: Bool = false,
         showsSuperKeyAlternative: Bool = false,
         superKeyModifiers: GlobalShortcutModifiers = .validMask,
         includeInactiveConflicts: Bool = false,
         reservesClearButtonSpace: Bool = false,
         additionalConflict: @escaping (GlobalShortcut) -> String? = { _ in nil },
         onChange: @escaping () -> Void) {
        self.role = role
        self.isEnabled = isEnabled
        self.label = label
        self.symbolName = symbolName
        self.contextLabel = contextLabel
        self.statusText = statusText
        self.statusIsActive = statusIsActive
        self.showsSuperKeyAlternative = showsSuperKeyAlternative
        self.superKeyModifiers = superKeyModifiers
        self.includeInactiveConflicts = includeInactiveConflicts
        self.reservesClearButtonSpace = reservesClearButtonSpace
        self.additionalConflict = additionalConflict
        self.onChange = onChange
        _rawValue = AppStorage(wrappedValue: role.defaultShortcut.storageValue, role.storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                ShortcutRowLabel(title: label ?? l10n.s.shelfHotkeyLabel,
                                 symbolName: symbolName,
                                 contextLabel: contextLabel,
                                 statusText: statusText,
                                 statusIsActive: statusIsActive)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        ShortcutRecorderButton(shortcut: pendingTakeOver ?? shortcut,
                                               isEnabled: isEnabled,
                                               waitingTitle: l10n.s.shortcutPressKeys,
                                               notCapturedAction: { errorText = l10n.s.shortcutNotCaptured },
                                               recordingChanged: { recording in
                                                   isRecording = recording
                                                   if recording {
                                                       errorText = nil
                                                       pendingTakeOver = nil
                                                   }
                                               },
                                               invalidAction: {
                                                   errorText = l10n.s.shortcutInvalid
                                               },
                                               captureAction: save)
                            .frame(width: 108)
                            .disabled(!isEnabled)
                        if reservesClearButtonSpace {
                            // Rows beside it have a clear button here; keep the
                            // recorders in one column.
                            Image(systemName: "xmark.circle.fill")
                                .hidden()
                                .accessibilityHidden(true)
                        }
                        Button(l10n.s.shortcutReset) {
                            rawValue = role.defaultShortcut.storageValue
                            errorText = nil
                            pendingTakeOver = nil
                            SystemShortcutTakeover.setTakeOver(role.storageKey, false)
                            onChange()
                        }
                        .disabled(!isEnabled || shortcut == role.defaultShortcut)
                    }
                    if let alternative = superKeyAlternative {
                        Text(String(format: FeatureStrings.shortcuts(l10n.language)
                            .superKeyAlternativeFormat, alternative))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(alternative)
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if isRecording {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let pendingTakeOver {
                SystemShortcutTakeOverOffer(shortcut: pendingTakeOver,
                                            onAccept: {
                                                rawValue = pendingTakeOver.storageValue
                                                SystemShortcutTakeover.setTakeOver(role.storageKey, true)
                                                self.pendingTakeOver = nil
                                                onChange()
                                            },
                                            onDismiss: {
                                                self.pendingTakeOver = nil
                                                errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
                                            })
            }
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
    }

    private var shortcut: GlobalShortcut {
        GlobalShortcut(storageValue: rawValue) ?? role.defaultShortcut
    }

    private var superKeyAlternative: String? {
        guard showsSuperKeyAlternative else { return nil }
        return shortcut.superKeyAlternative(
            sourceLabel: FeatureStrings.superKey(l10n.language).sourceLabel(superKey.source),
            superKeyModifiers: superKeyModifiers)
    }

    private func save(_ shortcut: GlobalShortcut) {
        if let conflict = GlobalShortcutRole.conflict(for: shortcut,
                                                      excluding: role,
                                                      includeInactive: includeInactiveConflicts) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s))
            return
        }
        if let conflict = additionalConflict(shortcut) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict)
            return
        }
        // Nothing claims this row's key, so accepting an offer would write an
        // opt-in no feature ever resolves: refuse the combination the way the
        // row did before the take-over existed. The live table alone is the
        // right question here, and its blindness to a key already switched off
        // is what still lets the switcher's rows record the ids its own
        // take-over toggle is holding.
        if !role.supportsTakeOver, shortcut.conflictsWithSystemShortcut(for: role) {
            errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
            return
        }
        // The offer is the last word on a combination: every other check has
        // already passed, so accepting it writes exactly what a save writes.
        switch SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut,
            conflictsWithMacOS: role.supportsTakeOver
                && SystemShortcutTakeover.conflictsWithMacOS(shortcut, for: role),
            takenOver: SystemShortcutTakeover.isTakenOver(role.storageKey),
            current: GlobalShortcut(storageValue: rawValue)) {
        case .offer:
            pendingTakeOver = shortcut
            errorText = nil
            return
        case .save(let clearTakeOver):
            rawValue = shortcut.storageValue
            errorText = nil
            if clearTakeOver { SystemShortcutTakeover.setTakeOver(role.storageKey, false) }
        }
        onChange()
    }
}

struct ShortcutRowLabel: View {
    let title: String
    let symbolName: String?
    let contextLabel: String?
    let statusText: String?
    let statusIsActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            if let symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if contextLabel != nil || statusText != nil {
                    HStack(spacing: 5) {
                        if let contextLabel {
                            Text(contextLabel)
                        }
                        if contextLabel != nil, statusText != nil {
                            Text("•")
                        }
                        if let statusText {
                            Circle()
                                .fill(statusIsActive ? Color.green : Color.secondary)
                                .frame(width: 5, height: 5)
                            Text(statusText)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Compact Shortcut Preference Row

struct CompactShortcutPreferenceRow: View {
    let title: String
    let role: GlobalShortcutRole
    let enabledKey: String
    var onChange: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
            Spacer()
            CompactShortcutRecorder(role: role, enabledKey: enabledKey, onChange: onChange)
        }
    }
}

@MainActor
final class CompactShortcutCoordinator: ObservableObject {
    static let shared = CompactShortcutCoordinator()
    @Published var activeRole: GlobalShortcutRole?

    func startRecording(role: GlobalShortcutRole) {
        if activeRole != role {
            if activeRole != nil {
                ShortcutCapture.end()
            }
            activeRole = role
            ShortcutCapture.begin()
        }
    }

    func stopRecording(role: GlobalShortcutRole? = nil) {
        if let role {
            if activeRole == role {
                activeRole = nil
                ShortcutCapture.end()
            }
        } else {
            if activeRole != nil {
                activeRole = nil
                ShortcutCapture.end()
            }
        }
    }
}

struct CompactShortcutRecorder: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var coordinator = CompactShortcutCoordinator.shared
    let role: GlobalShortcutRole
    let enabledKey: String
    var onChange: () -> Void = {}

    @AppStorage private var isEnabled: Bool
    @AppStorage private var rawValue: String
    private var isRecording: Bool { coordinator.activeRole == role }
    @State private var pressedModifiers: GlobalShortcutModifiers = []
    @State private var errorText: String?
    @State private var isHovering = false
    @State private var shakeAttempts: CGFloat = 0

    private let recorderWidth: CGFloat = 140
    private let recorderHeight: CGFloat = 26

    init(role: GlobalShortcutRole,
         enabledKey: String,
         onChange: @escaping () -> Void = {}) {
        self.role = role
        self.enabledKey = enabledKey
        self.onChange = onChange
        _isEnabled = AppStorage(wrappedValue: false, enabledKey)
        _rawValue = AppStorage(wrappedValue: role.defaultShortcut.storageValue, role.storageKey)
    }

    private var shortcut: GlobalShortcut {
        GlobalShortcut(storageValue: rawValue) ?? role.defaultShortcut
    }

    private var isModifiedFromDefault: Bool {
        !isEnabled || (shortcut != role.defaultShortcut)
    }

    var body: some View {
        ZStack {
            Button {
                if isRecording {
                    coordinator.stopRecording(role: role)
                } else {
                    errorText = nil
                    pressedModifiers = []
                    coordinator.startRecording(role: role)
                }
            } label: {
                HStack(spacing: 4) {
                    if let errorText {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.red)
                        Text(errorText)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .lineLimit(1)
                    } else if isRecording {
                        if !pressedModifiers.isEmpty {
                            Text(pressedModifiers.keyCaps.joined(separator: " "))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text(l10n.s.shortcutPressKeys)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    } else if isEnabled {
                        Text(shortcut.displayString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.trailing, isModifiedFromDefault ? 40 : 22)
                            .padding(.leading, 8)
                    } else {
                        // Disabled / empty state
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isRecording && errorText == nil {
                HStack(spacing: 4) {
                    Spacer()
                    if isModifiedFromDefault {
                        Button(action: resetToDefault) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 16, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(l10n.s.shortcutReset)
                    }
                    if isEnabled {
                        Button(action: clearShortcut) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(width: 16, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(l10n.s.shortcutClear)
                    }
                }
                .padding(.trailing, 6)
            }
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
                    lineWidth: (isRecording || errorText != nil) ? 1.5 : (isHovering ? 0.8 : 0.5)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: coordinator.activeRole) { _, newRole in
            if newRole != role {
                pressedModifiers = []
            }
        }
        .onDisappear {
            coordinator.stopRecording(role: role)
        }
        .background {
            if isRecording {
                KeyCaptureBridgeView(
                    onKeyDown: { event in
                        handleKeyEvent(event)
                    },
                    onFlagsChanged: { event in
                        handleFlagsChanged(event)
                    }
                )
            }
        }
    }

    private var backgroundColor: Color {
        if errorText != nil {
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
        if errorText != nil {
            return Color.red
        } else if isRecording {
            return Color.accentColor
        } else if isHovering {
            return Color.primary.opacity(0.25)
        } else {
            return Color.primary.opacity(0.12)
        }
    }

    private func showError(_ text: String) {
        errorText = text
        NSSound.beep()
        withAnimation(.default) {
            shakeAttempts += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.errorText == text {
                self.errorText = nil
            }
        }
    }

    private func resetToDefault() {
        let targetShortcut = role.defaultShortcut
        // Reset never rewrites another feature's shortcut or enable switches.
        guard case .save(let clearTakeOver)? = validationDecision(targetShortcut) else { return }
        rawValue = targetShortcut.storageValue
        isEnabled = true
        errorText = nil
        if clearTakeOver { SystemShortcutTakeover.setTakeOver(role.storageKey, false) }
        onChange()
    }

    private func validationDecision(_ shortcut: GlobalShortcut) -> RecorderTakeOverDecision? {
        guard shortcut.isValid else {
            showError(l10n.s.shortcutInvalid)
            return nil
        }
        if let conflict = GlobalShortcutRole.conflict(for: shortcut, excluding: role) {
            showError(String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s)))
            return nil
        }
        let conflictsWithMacOS = role.supportsTakeOver
            ? SystemShortcutTakeover.conflictsWithMacOS(shortcut, for: role)
            : shortcut.conflictsWithSystemShortcut(for: role)
        if conflictsWithMacOS && !role.supportsTakeOver {
            showError(String(format: l10n.s.shortcutConflictFormat, "macOS"))
            return nil
        }
        let decision = SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut, conflictsWithMacOS: conflictsWithMacOS,
            takenOver: SystemShortcutTakeover.isTakenOver(role.storageKey),
            current: GlobalShortcut(storageValue: rawValue))
        if case .offer = decision {
            showError(String(format: l10n.s.shortcutConflictFormat, "macOS"))
            return nil
        }
        return decision
    }

    private func clearShortcut() {
        isEnabled = false
        errorText = nil
        onChange()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        pressedModifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            coordinator.stopRecording(role: role)
            return
        }
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        if GlobalShortcut.clearsShortcut(keyCode: Int64(event.keyCode), modifiers: modifiers) {
            clearShortcut()
            coordinator.stopRecording(role: role)
            return
        }
        let captured = GlobalShortcut(keyCode: Int64(event.keyCode), modifiers: modifiers)
        guard case .save(let clearTakeOver)? = validationDecision(captured) else { return }
        rawValue = captured.storageValue
        if clearTakeOver { SystemShortcutTakeover.setTakeOver(role.storageKey, false) }
        isEnabled = true
        errorText = nil
        coordinator.stopRecording(role: role)
        onChange()
    }
}

private struct CompactRecorderShakeEffect: GeometryEffect {
    var amount: CGFloat = 6
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * shakesPerUnit),
            y: 0))
    }
}

private struct KeyCaptureBridgeView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void
    var onFlagsChanged: (NSEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown, onFlagsChanged: onFlagsChanged)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKeyDown = onKeyDown
        context.coordinator.onFlagsChanged = onFlagsChanged
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    @MainActor
    final class Coordinator {
        var onKeyDown: (NSEvent) -> Void
        var onFlagsChanged: (NSEvent) -> Void
        private var monitor: Any?

        init(onKeyDown: @escaping (NSEvent) -> Void, onFlagsChanged: @escaping (NSEvent) -> Void) {
            self.onKeyDown = onKeyDown
            self.onFlagsChanged = onFlagsChanged
        }

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                if event.type == .flagsChanged {
                    self?.onFlagsChanged(event)
                    return nil
                } else if event.type == .keyDown {
                    self?.onKeyDown(event)
                    return nil
                }
                return event
            }
        }

        func remove() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
