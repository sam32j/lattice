// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

/// "Close preview after focus changes" for the screenshot and recording
/// previews. A pinned image takes focus when the pointer merely passes over
/// it; the person did not move their focus, so that loss is ignored. The
/// preview then closes on the next real change instead: focus leaving the
/// pins for anything but the preview itself.
final class PreviewFocusLoss {
    private var observers: [NSObjectProtocol] = []
    private var lostPassively = false

    init(window: NSWindow, ignoresLoss: @escaping () -> Bool, onLoss: @escaping () -> Void) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window,
                                            queue: .main) { [weak self] _ in
            guard let self, !ignoresLoss() else { return }
            if ScreenshotPinController.grantsHoverFocus {
                self.lostPassively = true
                return
            }
            onLoss()
        })
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window,
                                            queue: .main) { [weak self] _ in
            self?.lostPassively = false
        })
        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: nil,
                                            queue: .main) { [weak self, weak window] note in
            guard let self, self.lostPassively, note.object is ScreenshotPinWindow else { return }
            // Read where focus went once AppKit has settled it.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, self.lostPassively else { return }
                let key = NSApp.keyWindow
                guard !(key is ScreenshotPinWindow), key !== window, !ignoresLoss() else { return }
                self.lostPassively = false
                onLoss()
            }
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
