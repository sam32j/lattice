// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Combine

extension QuitProtectionService {
    // MARK: Event routing

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // The key up that ends the swallow may be among the events missed.
            swallowShortcut = nil
            nativeSwitcherSessionActive = false
            cancelPending()
            let enabled = AppFeature.quitWindowProtection.isAvailable
                && isEnabledForAnyShortcut
            let shouldRearm = SessionActivitySupport.tapShouldRun(
                featureWanted: enabled,
                accessibilityGranted: AXIsProcessTrusted(),
                sessionIsActive: SessionActivity.shared.isActive
            )
            if shouldRearm, let tap {
                InputEventTap.enable(tap: tap, enable: true)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.stop()
                    self?.syncWithPreferences()
                }
            }
            return Unmanaged.passUnretained(event)
        }
        guard isRunning, !isSynthetic(event) else {
            return Unmanaged.passUnretained(event)
        }

        // The native switcher keeps the original app frontmost while another
        // app is selected. Its Q must reach the Dock, never a confirmation
        // targeting that original app. Track the Command chord without an AX
        // query on the tap, including reverse navigation and dismissal.
        if !event.flags.contains(.maskCommand) {
            nativeSwitcherSessionActive = false
        } else if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 48, !event.flags.contains(.maskControl),
               !event.flags.contains(.maskAlternate) {
                nativeSwitcherSessionActive = true
            } else if keyCode == 53 || (nativeSwitcherSessionActive
                && GlobalShortcut.layoutKeyLabel(for: keyCode, usesCommand: true) == ".") {
                nativeSwitcherSessionActive = false
            }
        }

        // Ordinary typing still avoids consulting another service. A
        // switcher-owned press must reach its tap, regardless of tap order.
        if (hasPressInFlight || event.flags.contains(.maskCommand)),
           deferToSwitcherIfNeeded() {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown: return handleKeyDown(event)
        case .keyUp: return handleKeyUp(event)
        case .flagsChanged:
            handleFlagsChanged(event)
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if keyCode == 53, pending != nil {
            cancelPending()
            return nil
        }

        // Every branch below either needs Command held or belongs to a press
        // already in flight, and reading which key this is costs an NSEvent
        // plus a layout lookup on a tap that sees every keystroke on the Mac.
        // Ordinary typing stops here.
        guard event.flags.contains(.maskCommand) || hasPressInFlight else {
            return Unmanaged.passUnretained(event)
        }

        let shortcut = matchingShortcut(for: event)

        if let swallowShortcut {
            if shortcut == swallowShortcut || isRepeat {
                return nil
            }
        }

        if let currentPending = pending {
            if shortcut != currentPending.shortcut {
                cancelPending()
            }
        }

        guard let shortcut else {
            return Unmanaged.passUnretained(event)
        }

        let configuration = configuration(for: shortcut)
        guard configuration.enabled,
              QuitProtectionSupport.scopeAllows(configuration.scope,
                                                bundleIdentifier: frontmostBundleIdentifier,
                                                exceptions: configuration.exceptions)
        else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let command = flags.contains(.maskCommand)
        if isRepeat, command {
            return nil
        }

        let control = flags.contains(.maskControl)
        let option = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)
        let character = NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.lowercased()
        let commandLabel = GlobalShortcut.layoutKeyLabel(for: keyCode, usesCommand: true)

        switch configuration.mode {
        case .hold:
            guard QuitProtectionSupport.isBaseShortcut(
                keyCharacter: character,
                keyCode: keyCode,
                commandLabel: commandLabel,
                command: command,
                control: control,
                option: option,
                shift: shift,
                shortcut: shortcut
            ) else {
                return Unmanaged.passUnretained(event)
            }
            beginPending(shortcut: shortcut, mode: .hold, event: event)
            showHUD(for: shortcut, configuration: configuration, extraModifierOnly: false)
            return nil

        case .doublePress:
            guard QuitProtectionSupport.isBaseShortcut(
                keyCharacter: character,
                keyCode: keyCode,
                commandLabel: commandLabel,
                command: command,
                control: control,
                option: option,
                shift: shift,
                shortcut: shortcut
            ) else {
                return Unmanaged.passUnretained(event)
            }
            if let pending, pending.shortcut == shortcut, pending.mode == .doublePress {
                if QuitProtectionSupport.isWithinDoublePressInterval(
                    firstTimestamp: pending.event.timestamp,
                    secondTimestamp: event.timestamp,
                    intervalMilliseconds: configuration.doublePressIntervalMilliseconds
                ) {
                    let targetPid = pending.targetProcessIdentifier
                    let generation = pending.switcherSessionGeneration
                    cancelPending()
                    swallowShortcut = shortcut
                    confirm(shortcut: shortcut, event: event, targetProcessIdentifier: targetPid,
                            switcherSessionGeneration: generation)
                    return nil
                }
            }
            beginPending(shortcut: shortcut, mode: .doublePress, event: event)
            showHUD(for: shortcut, configuration: configuration, extraModifierOnly: false)
            return nil

        case .extraModifier:
            if QuitProtectionSupport.isExtraShortcut(
                keyCharacter: character,
                keyCode: keyCode,
                commandLabel: commandLabel,
                command: command,
                control: control,
                option: option,
                shift: shift,
                shortcut: shortcut,
                extraModifier: configuration.extraModifier
            ) {
                cancelPending()
                swallowShortcut = shortcut
                confirm(shortcut: shortcut,
                        event: event,
                        targetProcessIdentifier: frontmostProcessIdentifier,
                        removing: configuration.extraModifier)
                return nil
            }
            guard QuitProtectionSupport.isBaseShortcut(
                keyCharacter: character,
                keyCode: keyCode,
                commandLabel: commandLabel,
                command: command,
                control: control,
                option: option,
                shift: shift,
                shortcut: shortcut
            ) else {
                return Unmanaged.passUnretained(event)
            }
            beginPending(shortcut: shortcut, mode: .extraModifier, event: event)
            showHUD(for: shortcut, configuration: configuration, extraModifierOnly: true)
            return nil
        }
    }

    func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        // A release only matters to a press this service is holding. Command
        // cannot be required here the way it is above: the release of Q may
        // well arrive after Command was let go.
        guard hasPressInFlight else {
            return Unmanaged.passUnretained(event)
        }

        let shortcut = matchingShortcut(for: event)

        if let swallow = swallowShortcut, shortcut == swallow {
            self.swallowShortcut = nil
            return nil
        }

        guard let pending else {
            return Unmanaged.passUnretained(event)
        }

        guard shortcut == pending.shortcut else {
            return Unmanaged.passUnretained(event)
        }

        switch pending.mode {
        case .hold:
            cancelPending()
            return nil

        case .doublePress:
            return nil

        case .extraModifier:
            cancelPending()
            return nil
        }
    }

    func handleFlagsChanged(_ event: CGEvent) {
        guard pending != nil else { return }
        let flags = event.flags
        let commandHeld = flags.contains(.maskCommand)
        if !commandHeld {
            cancelPending()
        }
    }

}
