// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Combine

extension QuitProtectionService {
    // MARK: Confirmation state

    /// A session may begin and end without this tap seeing a key: the
    /// switcher can swallow it first. Invalidate old confirmations by the
    /// existing session generation, not by panel visibility or notifications.
    func deferToSwitcherIfNeeded() -> Bool {
        let ownership = AppSwitcher.shared.keyboardInputOwnership
        if ownership.isOwned { nativeSwitcherSessionActive = false }
        let switcherOwnsInput = ownership.isOwned || nativeSwitcherSessionActive
        let stalePending = pending.map {
            $0.switcherSessionGeneration != ownership.generation
        } ?? false
        if switcherOwnsInput || stalePending {
            if hasPressInFlight {
                cancelPending()
                swallowShortcut = nil
            }
        }
        return switcherOwnsInput
    }

    func beginPending(shortcut: QuitProtectionShortcut,
                              mode: QuitProtectionMode,
                              event: CGEvent) {
        holdTimer?.invalidate()
        holdTimer = nil
        pendingExpiry?.cancel()
        pendingExpiry = nil
        pending = Pending(shortcut: shortcut,
                          event: event,
                          mode: mode,
                          targetProcessIdentifier: frontmostProcessIdentifier,
                          switcherSessionGeneration: AppSwitcher.shared.keyboardInputOwnership.generation)

        let configuration = configuration(for: shortcut)
        switch mode {
        case .hold:
            holdTimer = Timer.scheduledTimer(withTimeInterval:
                QuitProtectionSupport.sanitizedHoldDuration(configuration.holdDurationMilliseconds) / 1_000,
                repeats: false
            ) { [weak self] _ in self?.completeHold() }
        case .doublePress:
            let expiry = DispatchWorkItem { [weak self] in
                guard let self, self.pending?.mode == .doublePress else { return }
                self.cancelPending()
            }
            pendingExpiry = expiry
            DispatchQueue.main.asyncAfter(deadline: .now()
                + (QuitProtectionSupport.sanitizedDoublePressInterval(
                    configuration.doublePressIntervalMilliseconds
                ) + 100) / 1_000,
                                           execute: expiry)
        case .extraModifier:
            let expiry = DispatchWorkItem { [weak self] in
                guard let self, self.pending?.mode == .extraModifier else { return }
                self.cancelPending()
            }
            pendingExpiry = expiry
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: expiry)
        }
    }

    func completeHold() {
        guard !deferToSwitcherIfNeeded(),
              let pending, pending.mode == .hold else { return }
        let shortcut = pending.shortcut
        let event = pending.event
        let targetPid = pending.targetProcessIdentifier
        let generation = pending.switcherSessionGeneration

        swallowShortcut = shortcut
        cancelPending()

        confirm(shortcut: shortcut, event: event, targetProcessIdentifier: targetPid,
                switcherSessionGeneration: generation)
    }

    func cancelPending() {
        holdTimer?.invalidate()
        holdTimer = nil
        pendingExpiry?.cancel()
        pendingExpiry = nil
        pending = nil
        hideHUD()
    }

    // MARK: Preferences and presentation

    func configuration(for shortcut: QuitProtectionShortcut) -> QuitProtectionConfiguration {
        let defaults = UserDefaults.standard
        let enabledKey = shortcut == .quit ? DefaultsKey.quitProtectionQuitEnabled : DefaultsKey.quitProtectionCloseEnabled
        let modeKey = shortcut == .quit ? DefaultsKey.quitProtectionQuitMode : DefaultsKey.quitProtectionCloseMode
        let holdKey = shortcut == .quit ? DefaultsKey.quitProtectionQuitHoldDurationMs : DefaultsKey.quitProtectionCloseHoldDurationMs
        let doubleKey = shortcut == .quit ? DefaultsKey.quitProtectionQuitDoubleIntervalMs : DefaultsKey.quitProtectionCloseDoubleIntervalMs
        let modifierKey = shortcut == .quit ? DefaultsKey.quitProtectionQuitExtraModifier : DefaultsKey.quitProtectionCloseExtraModifier
        let scopeKey = shortcut == .quit ? DefaultsKey.quitProtectionQuitScope : DefaultsKey.quitProtectionCloseScope
        let feedbackKey = shortcut == .quit ? DefaultsKey.quitProtectionQuitShowFeedback : DefaultsKey.quitProtectionCloseShowFeedback
        return QuitProtectionConfiguration(
            enabled: defaults.bool(forKey: enabledKey),
            mode: QuitProtectionSupport.modeFor(defaults.string(forKey: modeKey)),
            holdDurationMilliseconds: QuitProtectionSupport.sanitizedHoldDuration(defaults.double(forKey: holdKey)),
            doublePressIntervalMilliseconds: QuitProtectionSupport.sanitizedDoublePressInterval(defaults.double(forKey: doubleKey)),
            extraModifier: QuitProtectionSupport.extraModifierFor(defaults.string(forKey: modifierKey)),
            scope: QuitProtectionSupport.scopeFor(defaults.string(forKey: scopeKey)),
            exceptions: exceptions(for: shortcut),
            showFeedback: defaults.bool(forKey: feedbackKey)
        )
    }

    func exceptionsKey(for shortcut: QuitProtectionShortcut) -> String {
        shortcut == .quit ? DefaultsKey.quitProtectionQuitExceptions : DefaultsKey.quitProtectionCloseExceptions
    }

    func showHUD(for shortcut: QuitProtectionShortcut,
                         configuration: QuitProtectionConfiguration,
                         extraModifierOnly: Bool) {
        guard configuration.showFeedback, let press = pending else { return }
        let strings = FeatureStrings.quitProtection(L10n.shared.language)
        let title: String
        if extraModifierOnly {
            title = String(format: strings.extraHUDFormat(for: shortcut),
                           "\(modifierSymbol(configuration.extraModifier))\(shortcut.symbol)")
        } else if configuration.mode == .hold {
            title = String(format: strings.holdHUDFormat(for: shortcut), shortcut.symbol)
        } else {
            title = String(format: strings.doubleHUDFormat(for: shortcut), shortcut.symbol)
        }
        let deadline = configuration.mode == .hold ? holdTimer?.fireDate : nil
        QuitProtectionHUD.resolveTargetWindow(forPID: press.targetProcessIdentifier) { [weak self] targetRect in
            guard let self, self.isRunning, !self.deferToSwitcherIfNeeded(),
                  self.pending?.id == press.id,
                  self.frontmostProcessIdentifier == press.targetProcessIdentifier,
                  SessionActivity.shared.isActive, AXIsProcessTrusted(),
                  AppFeature.quitWindowProtection.isAvailable,
                  self.configuration(for: shortcut) == configuration,
                  deadline.map({ $0 > Date() }) ?? true else { return }
            self.hud.show(title: title, detail: strings.cancelHint,
                          holdDeadline: deadline, targetRect: targetRect)
        }
    }

    func hideHUD() { hud.hide() }

    // MARK: Selection confirmation

    /// What the switcher needs to confirm a protected Q or W on its own. It
    /// acts on the item it has selected rather than on the frontmost app, so
    /// the tap above deliberately yields and cannot answer for it.
    struct SelectionConfirmation {
        let intervalMilliseconds: Double
        let showsFeedback: Bool
    }

    /// Nil when this shortcut is unprotected for that app, which leaves the
    /// switcher's immediate behavior exactly as it was.
    func selectionConfirmation(for shortcut: QuitProtectionShortcut,
                               bundleIdentifier: String?) -> SelectionConfirmation? {
        guard AppFeature.quitWindowProtection.isAvailable else { return nil }
        let configuration = configuration(for: shortcut)
        guard configuration.enabled,
              QuitProtectionSupport.scopeAllows(configuration.scope,
                                                bundleIdentifier: bundleIdentifier,
                                                exceptions: configuration.exceptions)
        else { return nil }
        return SelectionConfirmation(
            intervalMilliseconds: QuitProtectionSupport.sanitizedDoublePressInterval(
                configuration.doublePressIntervalMilliseconds),
            showsFeedback: configuration.showFeedback)
    }

    /// The same panel the tap uses, so both places ask for the second press
    /// in the same words and the same place.
    func showSelectionHUD(for shortcut: QuitProtectionShortcut, on screen: NSScreen?) {
        let strings = FeatureStrings.quitProtection(L10n.shared.language)
        hud.show(title: String(format: strings.doubleHUDFormat(for: shortcut), shortcut.character.uppercased()),
                 detail: strings.cancelHint,
                 on: screen)
    }

    func hideSelectionHUD() { hud.hide() }

    func modifierSymbol(_ modifier: QuitProtectionExtraModifier) -> String {
        switch modifier {
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }

}
