// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

/// One transient key, never a string of typed text or a persisted key log.
struct RecorderKeystrokeState {
    private var text: String?
    private var expires: TimeInterval = 0
    mutating func clear() { text = nil; expires = 0 }
    func label(at time: TimeInterval) -> String? { time < expires ? text : nil }

    mutating func consume(_ event: NSEvent, enabled: Bool, recording: Bool,
                          paused: Bool, secureInput: Bool, at time: TimeInterval) {
        guard enabled, recording, !paused, !secureInput, time.isFinite else { clear(); return }
        guard event.type == .keyDown, !event.isARepeat else { return }
        let special: [Int: String] = [kVK_Return: "↩", kVK_ANSI_KeypadEnter: "↩", kVK_Escape: "⎋",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Tab: "⇥", kVK_Space: "Space",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"]
        let key: String
        if let symbol = special[Int(event.keyCode)] { key = symbol }
        else if let characters = event.charactersIgnoringModifiers, characters.count == 1,
                characters.rangeOfCharacter(from: .controlCharacters) == nil { key = characters.uppercased() }
        else { clear(); return }
        let flags = event.modifierFlags
        text = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + key
        expires = time + 0.9
    }
}

/// Installed only for an enabled, active recording. No monitor exists while
/// selecting an area, waiting for Play, or after cancellation.
final class RecorderKeystrokeOverlay {
    private let frames: RecorderOverlayFrameStore
    private var pauseClock: RecorderPauseClock?
    private var local: Any?
    private var global: Any?
    private var timer: Timer?
    private var state = RecorderKeystrokeState()
    private var displayed: String?
    var onImage: ((CGImage?) -> Void)?

    init(frames: RecorderOverlayFrameStore) { self.frames = frames }

    func start(pauseClock: RecorderPauseClock) {
        stop()
        self.pauseClock = pauseClock
        global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] in self?.consume($0) }
        local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.consume(event)
            return event
        }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        if let local { NSEvent.removeMonitor(local) }
        if let global { NSEvent.removeMonitor(global) }
        local = nil
        global = nil
        timer?.invalidate()
        timer = nil
        pauseClock = nil
        state.clear()
        displayed = nil
        frames.setKeys(nil)
        onImage?(nil)
    }

    private func consume(_ event: NSEvent) {
        state.consume(event, enabled: true, recording: pauseClock != nil,
            paused: pauseClock?.isPaused ?? true, secureInput: IsSecureEventInputEnabled(), at: CACurrentMediaTime())
        refresh()
    }
    private func refresh() {
        if pauseClock?.isPaused != false || IsSecureEventInputEnabled() { state.clear() }
        let text = state.label(at: CACurrentMediaTime())
        if text == nil { state.clear() }
        guard text != displayed else { return }
        displayed = text
        let image = text.flatMap(Self.render)
        frames.setKeys(image)
        onImage?(image)
    }

    private static func render(_ text: String) -> CGImage? {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 28, weight: .medium),
                                                       .foregroundColor: NSColor.white]
        let width = Int(ceil((text as NSString).size(withAttributes: attributes).width)) + 28
        guard let context = CGContext(data: nil, width: width, height: 54, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { NSSound.beep(); return nil }
        context.setFillColor(CGColor(gray: 0.08, alpha: 0.85))
        context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: 54),
                              cornerWidth: 12, cornerHeight: 12, transform: nil))
        context.fillPath()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (text as NSString).draw(at: CGPoint(x: 14, y: 10), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }
}
