// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Carbon.HIToolbox
import Combine
import Foundation

/// Cycles the system output through the devices selected in the mixer panel.
final class SoundOutputSwitcher: ObservableObject {
    static let shared = SoundOutputSwitcher()

    @Published private(set) var registrationFailed = false
    @Published private(set) var lastSwitchFailed = false
    @Published private(set) var skippedUIDs: Set<String> = []

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var registeredShortcut: GlobalShortcut?

    private init() {
        skippedUIDs = Set(UserDefaults.standard.stringArray(forKey: DefaultsKey.soundOutputSwitcherSkippedUIDs) ?? [])
    }

    func syncWithPreferences() {
        AppFeature.soundOutputSwitcher.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.soundOutputSwitcherEnabled)
            ? registerHotkey()
            : unregisterHotkey()
    }

    func stop() {
        unregisterHotkey()
    }

    func skippedDeviceUIDs() -> Set<String> {
        skippedUIDs
    }

    func isSkipped(_ uid: String) -> Bool {
        skippedUIDs.contains(uid)
    }

    func setSkipped(_ skipped: Bool, for uid: String) {
        if skipped {
            skippedUIDs.insert(uid)
        } else {
            skippedUIDs.remove(uid)
        }
        UserDefaults.standard.set(Array(skippedUIDs).sorted(), forKey: DefaultsKey.soundOutputSwitcherSkippedUIDs)
    }

    func toggleSkip(for uid: String) {
        setSkipped(!isSkipped(uid), for: uid)
    }

    func cycleDeviceUIDs() -> [String] {
        let priorityOrder = AudioPriorityService.shared.outputPriorityUIDs
        let hardwareUIDs = AppVolumeMixer.shared.outputDevices.filter(\.canBeDefaultOutput).map(\.uid)
        var ordered = priorityOrder
        for uid in hardwareUIDs where !ordered.contains(uid) {
            ordered.append(uid)
        }
        let skipped = skippedDeviceUIDs()
        return ordered.filter { !skipped.contains($0) }
    }

    @discardableResult
    func switchToNextOutput() -> Bool {
        let ok = AppVolumeMixer.shared.switchToNextSoundOutput(in: cycleDeviceUIDs())
        lastSwitchFailed = !ok
        return ok
    }

    private func registerHotkey() {
        guard !InputEventTap.isBlocked else { unregisterHotkey(); return }
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.soundOutputSwitcherShortcut,
                                            fallback: .soundOutputSwitcherDefault)
        if hotKeyRef != nil, registeredShortcut == shortcut { return }
        unregisterHotkey()
        if eventHandler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                     eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                if let event {
                    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID), nil,
                                      MemoryLayout<EventHotKeyID>.size, nil, &id)
                }
                guard id.signature == 0x5655_534F, id.id == 4
                else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<SoundOutputSwitcher>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { if !InputEventTap.isBlocked { service.switchToNextOutput() } }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        }
        let id = EventHotKeyID(signature: 0x5655_534F, id: 4) // 'VUSO'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.carbonKeyCode,
                                         shortcut.carbonModifiers,
                                         id,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &ref)
        if status == noErr, let ref {
            hotKeyRef = ref
            registeredShortcut = shortcut
            registrationFailed = false
            SystemShortcutTakeover.claim(DefaultsKey.soundOutputSwitcherShortcut, shortcut: shortcut)
        } else {
            hotKeyRef = nil
            registeredShortcut = nil
            registrationFailed = true
        }
    }

    /// Lets go of the global key while a shortcut field is listening, so the
    /// user can record the very combination this feature uses. The next
    /// `syncWithPreferences` takes it back.
    func suspendShortcut() { unregisterHotkey() }

    private func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            SystemShortcutTakeover.release(DefaultsKey.soundOutputSwitcherShortcut)
        }
        hotKeyRef = nil
        registeredShortcut = nil
        registrationFailed = false
        lastSwitchFailed = false
    }
}
