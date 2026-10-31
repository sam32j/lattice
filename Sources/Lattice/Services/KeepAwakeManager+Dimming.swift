import AppKit
import Combine
import IOKit.ps
import IOKit.pwr_mgt
import os

extension KeepAwakeManager {
    // MARK: - Closed-lid screen dimming

    /// Runs whenever the closed-lid mode or the dimming preference changes.
    /// An `IOPMrootDomain` general-interest notification is cheaper than
    /// polling and is already how `BrightnessService` watches the lid for
    /// its own deferred-restoration case; this registers its own interest
    /// independently since the two features dim different things for
    /// different reasons. A restore still owed keeps the observer armed past
    /// the mode ending, the same way `BrightnessService`'s own deferred
    /// display restoration outlives whatever asked for it.
    func syncLidDimmingObserver() {
        let armed = clamshellActive && dimScreenOnLidClose
        if !armed { applyDimmingAction(LidDimmingSupport.restoring(saved: savedDisplayBrightness)) }
        guard armed || savedDisplayBrightness != nil else {
            if lidDimmingNotification != 0 { IOObjectRelease(lidDimmingNotification) }
            lidDimmingNotification = 0
            if let lidDimmingNotificationPort { IONotificationPortDestroy(lidDimmingNotificationPort) }
            lidDimmingNotificationPort = nil
            lidClosedForDimming = nil
            return
        }
        guard lidDimmingNotificationPort == nil else { return }
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return }
        defer { IOObjectRelease(root) }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        let result = IOServiceAddInterestNotification(
            port, root, kIOGeneralInterest, { context, _, _, _ in
                guard let context else { return }
                let manager = Unmanaged<KeepAwakeManager>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async { [weak manager] in manager?.lidStateMayHaveChangedForDimming() }
            }, Unmanaged.passUnretained(self).toOpaque(), &lidDimmingNotification)
        guard result == KERN_SUCCESS else {
            IONotificationPortDestroy(port)
            return
        }
        lidDimmingNotificationPort = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        lidClosedForDimming = BrightnessService.lidClosed()
        // The option can be enabled from an external display while the lid is
        // already shut. No transition follows registration in that case.
        if armed, lidClosedForDimming == true, savedDisplayBrightness == nil {
            applyDimmingAction(LidDimmingSupport.lidClosed(
                currentBrightness: LidDisplayDimmer.currentBrightness()))
        }
    }

    /// General interest fires on far more than lid transitions, so the
    /// current state is compared against what was last seen rather than
    /// assumed from the notification itself. The armed check also catches a
    /// callback already queued when the feature was torn down: it lands here
    /// as a no-op instead of acting on a mode that already ended.
    func lidStateMayHaveChangedForDimming() {
        guard (clamshellActive && dimScreenOnLidClose) || savedDisplayBrightness != nil else { return }
        let closed = BrightnessService.lidClosed() ?? false
        guard closed != lidClosedForDimming else { return }
        lidClosedForDimming = closed
        if closed {
            if clamshellActive, dimScreenOnLidClose {
                applyDimmingAction(LidDimmingSupport.lidClosed(currentBrightness: LidDisplayDimmer.currentBrightness()))
            }
        } else {
            applyDimmingAction(LidDimmingSupport.restoring(saved: savedDisplayBrightness))
        }
    }

    func applyDimmingAction(_ action: LidDimmingSupport.Action) {
        switch action {
        case .dim(let save):
            savedDisplayBrightness = save
            UserDefaults.standard.set(save, forKey: DefaultsKey.dimmedDisplaySavedBrightness)
            LidDisplayDimmer.setBrightness(0)
            Self.log.log("lid closed: dimmed the built-in display, saved \(save)")
        case .restore(let value):
            attemptDisplayRestore(value)
        case .none:
            break
        }
    }

    /// Keeps the saved level and its recovery marker until a write actually
    /// reports success — clearing them on a merely attempted write, the same
    /// way `BrightnessService`'s deferred restoration never drops a display
    /// it could not yet bring back, would leave the panel at zero forever if
    /// it is not in the online list yet (right as the lid opens) or the
    /// write itself fails. A few retries a half second apart cover that
    /// startup race; if the panel is still not back after those, whatever
    /// keeps `syncLidDimmingObserver` armed for an owed restore is what
    /// finds the next real lid-open event to try again.
    func attemptDisplayRestore(_ value: Double, attemptsLeft: Int = 6) {
        guard LidDisplayDimmer.setBrightness(value) else {
            Self.log.log("restoring the built-in display to \(value) found no panel yet, \(attemptsLeft - 1) retries left")
            guard attemptsLeft > 1 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.attemptDisplayRestore(value, attemptsLeft: attemptsLeft - 1)
            }
            return
        }
        savedDisplayBrightness = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.dimmedDisplaySavedBrightness)
        Self.log.log("restored the built-in display to \(value)")
        syncLidDimmingObserver()
    }

}
