import SwiftUI

extension MouseButtonShortcutsSection {
    // MARK: - Capture

    func startCapture() {
        stopSpacesCapture()
        captureFeedback = nil
        capturing = true
        MouseButtonShortcutService.shared.setCapturing(true)
        if !permissions.accessibility {
            permissions.requestAccessibility()
        }
    }

    func stopCapture() {
        guard capturing else { return }
        capturing = false
        captureFeedback = nil
        MouseButtonShortcutService.shared.setCapturing(false)
    }

    func handleCapture(_ seen: Int64?) {
        guard capturing, let seen else { return }
        if !MouseButtonShortcutSupport.canMap(seen) {
            captureFeedback = text.captureUnsupported
        } else if RadialMenuSupport.claimsMouseButton(seen) {
            captureFeedback = text.captureWheel
        } else if mappings[seen] != nil || pendingButton == seen
                    || (spacesEnabled && Int64(spacesButton) == seen) {
            captureFeedback = text.captureExists
        } else {
            pendingButton = seen
            recordError = nil
            stopCapture()
        }
    }

    func startSpacesCapture() {
        stopCapture()
        spacesFeedback = nil
        spacesCapturing = true
        MouseButtonShortcutService.shared.setCapturing(true)
        if !permissions.accessibility {
            permissions.requestAccessibility()
        }
    }

    func stopSpacesCapture() {
        guard spacesCapturing else { return }
        spacesCapturing = false
        spacesFeedback = nil
        MouseButtonShortcutService.shared.setCapturing(false)
    }

    /// The drag needs a button that can be held and moved, and one no other
    /// mouse feature is already answering for. A refusal explains itself
    /// instead of leaving the press looking ignored.
    func handleSpacesCapture(_ seen: Int64?) {
        guard spacesCapturing, let seen else { return }
        if !MouseSpacesGestureSupport.canBind(seen) {
            spacesFeedback = text.spacesCaptureUnsupported
        } else if RadialMenuSupport.claimsMouseButton(seen) {
            spacesFeedback = text.captureWheel
        } else if mappings[seen] != nil || pendingButton == seen {
            spacesFeedback = text.spacesCaptureExists
        } else {
            // Set before the capture ends, so the sync that ends it already
            // sees the new button.
            spacesButton = Int(seen)
            stopSpacesCapture()
        }
    }

    // MARK: - Persistence

    func setRecordError(_ message: String?, _ button: Int64) {
        recordError = message
        recordErrorButton = message == nil ? nil : button
    }

    func save(button: Int64, shortcut: GlobalShortcut) {
        mappings[button] = shortcut
        if pendingButton == button { pendingButton = nil }
        setRecordError(nil, button)
        persist()
    }

    func remove(_ button: Int64) {
        if recordErrorButton == button { setRecordError(nil, button) }
        if pendingButton == button {
            pendingButton = nil
            return
        }
        mappings.removeValue(forKey: button)
        persist()
    }

    func persist() {
        UserDefaults.standard.set(MouseButtonShortcutSupport.encode(mappings),
                                  forKey: DefaultsKey.mouseButtonShortcuts)
        MouseButtonShortcutService.shared.syncWithPreferences()
    }
}
