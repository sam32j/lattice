// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Combine

/// Guards only Command-Q and Command-W. The tap deliberately passes every
/// unrelated event without consulting the main app or Accessibility APIs.
final class QuitProtectionService: ObservableObject {
    static let shared = QuitProtectionService()

    @Published var isRunning = false
    @Published var revision = 0

    struct Pending {
        let id = UUID()
        let shortcut: QuitProtectionShortcut
        let event: CGEvent
        let mode: QuitProtectionMode
        let targetProcessIdentifier: pid_t?
        let switcherSessionGeneration: UInt64
    }

    static let syntheticMarker = OwnKeyEvent.quitProtectionMarker
    var tap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var activationObserver: NSObjectProtocol?
    var holdTimer: Timer?
    var pendingExpiry: DispatchWorkItem?
    var pending: Pending?
    var swallowShortcut: QuitProtectionShortcut?
    var nativeSwitcherSessionActive = false
    var frontmostBundleIdentifier: String?
    var frontmostProcessIdentifier: pid_t?
    let hud = QuitProtectionHUD()

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in
            self?.syncWithPreferences()
        }
    }

    func syncWithPreferences() {
        let enabled = AppFeature.quitWindowProtection.isAvailable
            && isEnabledForAnyShortcut
        guard SessionActivitySupport.tapShouldRun(
            featureWanted: enabled,
            accessibilityGranted: AXIsProcessTrusted(),
            sessionIsActive: SessionActivity.shared.isActive
        ) else {
            stop()
            return
        }
        start()
    }

    var isEnabledForAnyShortcut: Bool {
        configuration(for: .quit).enabled || configuration(for: .close).enabled
    }

    func exceptions(for shortcut: QuitProtectionShortcut) -> [String] {
        (UserDefaults.standard.array(forKey: exceptionsKey(for: shortcut)) as? [String] ?? [])
            .filter { !$0.isEmpty }
            .sorted()
    }

    func addException(_ bundleIdentifier: String, for shortcut: QuitProtectionShortcut) {
        var values = exceptions(for: shortcut)
        guard !bundleIdentifier.isEmpty, !values.contains(bundleIdentifier) else { return }
        values.append(bundleIdentifier)
        UserDefaults.standard.set(values.sorted(), forKey: exceptionsKey(for: shortcut))
        revision += 1
        syncWithPreferences()
    }

    func removeException(_ bundleIdentifier: String, for shortcut: QuitProtectionShortcut) {
        let values = exceptions(for: shortcut).filter { $0 != bundleIdentifier }
        UserDefaults.standard.set(values, forKey: exceptionsKey(for: shortcut))
        revision += 1
        syncWithPreferences()
    }

    // MARK: Lifecycle

    func start() {
        guard !isRunning else { return }
        guard installTap() else { return }
        isRunning = true
        let frontmost = NSWorkspace.shared.frontmostApplication
        frontmostBundleIdentifier = frontmost?.bundleIdentifier
        frontmostProcessIdentifier = frontmost?.processIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            self?.applicationDidActivate(app)
        }
    }

    func applicationDidActivate(_ app: NSRunningApplication) {
        if let pending, pending.targetProcessIdentifier != app.processIdentifier {
            cancelPending()
        }
        // The native switcher activates an app only as its session ends, and
        // a click on one of its icons ends it with Command still held.
        nativeSwitcherSessionActive = false
        frontmostBundleIdentifier = app.bundleIdentifier
        frontmostProcessIdentifier = app.processIdentifier
    }

    func stop() {
        cancelPending()
        swallowShortcut = nil
        nativeSwitcherSessionActive = false

        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil

        if let tap {
            InputEventTap.enable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isRunning = false
    }

    /// Releases the tap, its observer and any press in flight, for callers
    /// outside this type.
    func suspend() { stop() }

    func installTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let tap = InputEventTap.create(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<QuitProtectionService>
                    .fromOpaque(userInfo).takeUnretainedValue()
                return service.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        InputEventTap.enable(tap: tap, enable: true)
        return true
    }

    // MARK: Event helpers

    func matchingShortcut(for event: CGEvent) -> QuitProtectionShortcut? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let character = NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.lowercased()
        // Read from the keycap cache; this tap runs on the main run loop, so a
        // miss derives from the layout and backfills rather than answering nil.
        let commandLabel = GlobalShortcut.layoutKeyLabel(for: keyCode, usesCommand: true)
        return QuitProtectionShortcut.allCases.first {
            QuitProtectionSupport.matchesKey(keyCharacter: character,
                                             keyCode: keyCode,
                                             commandLabel: commandLabel,
                                             shortcut: $0)
        }
    }

    /// A press this service took over: either waiting for the confirmation
    /// that lets it through, or waiting for the release that closes it. Both
    /// make the keys that follow this service's business.
    var hasPressInFlight: Bool { pending != nil || swallowShortcut != nil }

    func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker
    }

    func confirm(shortcut: QuitProtectionShortcut,
                         event: CGEvent,
                         targetProcessIdentifier: pid_t?,
                         removing modifier: QuitProtectionExtraModifier? = nil,
                         switcherSessionGeneration: UInt64? = nil) {
        let ownership = AppSwitcher.shared.keyboardInputOwnership
        guard !ownership.isOwned, !nativeSwitcherSessionActive,
              switcherSessionGeneration.map({ $0 == ownership.generation }) ?? true else {
            cancelPending()
            swallowShortcut = nil
            return
        }
        let targetApp = targetProcessIdentifier.flatMap(NSRunningApplication.init(processIdentifier:))
        let targetBundleIdentifier = targetApp?.bundleIdentifier ?? frontmostBundleIdentifier
        if QuitProtectionSupport.usesNativeQuitRequest(for: shortcut,
                                                      bundleIdentifier: targetBundleIdentifier,
                                                      confirmedWithExtraModifier: modifier != nil),
           requestQuit(targetProcessIdentifier: targetProcessIdentifier) {
            return
        }
        postSyntheticPress(from: event, removing: modifier)
    }

    @discardableResult
    func requestQuit(targetProcessIdentifier: pid_t?) -> Bool {
        guard let targetProcessIdentifier,
              let app = NSRunningApplication(processIdentifier: targetProcessIdentifier)
        else { return false }
        return app.terminate()
    }

    /// Answers whether the press was posted, so a failed copy never leaves the
    /// key up travelling alone.
    func postSyntheticKeyDown(from event: CGEvent,
                                      removing modifier: QuitProtectionExtraModifier? = nil) -> Bool {
        guard let copy = event.copy() else { return false }
        if let modifier { copy.flags = flags(for: event, removing: modifier) }
        copy.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        copy.post(tap: .cghidEventTap)
        return true
    }

    func postSyntheticKeyUp(from event: CGEvent,
                                    removing modifier: QuitProtectionExtraModifier? = nil) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let copy = CGEvent(keyboardEventSource: nil,
                                 virtualKey: CGKeyCode(keyCode),
                                 keyDown: false) else { return }
        copy.flags = modifier.map { flags(for: event, removing: $0) } ?? event.flags
        copy.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        copy.post(tap: .cghidEventTap)
    }

    func postSyntheticPress(from event: CGEvent,
                                    removing modifier: QuitProtectionExtraModifier? = nil) {
        guard postSyntheticKeyDown(from: event, removing: modifier) else { return }
        postSyntheticKeyUp(from: event, removing: modifier)
    }

    func flags(for event: CGEvent,
                       removing modifier: QuitProtectionExtraModifier) -> CGEventFlags {
        var flags = event.flags
        switch modifier {
        case .shift: flags.remove(.maskShift)
        case .option: flags.remove(.maskAlternate)
        case .control: flags.remove(.maskControl)
        }
        return flags
    }
}
