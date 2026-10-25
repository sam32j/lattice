// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices

extension KeepAwakeManager {
    // MARK: - Optional pointer activity

    func syncMouseJiggleTimer() {
        guard isActive,
              !sessionPausedForScreenLock,
              AXIsProcessTrusted(),
              UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeMouseJiggleEnabled)
        else {
            stopMouseJiggleTimer()
            return
        }

        let minutes = Defaults.sanitizedKeepAwakeMouseJiggleInterval(
            UserDefaults.standard.integer(forKey: DefaultsKey.keepAwakeMouseJiggleInterval)
        )
        let interval = TimeInterval(minutes * 60)
        if mouseJiggleTimer?.timeInterval == interval { return }

        stopMouseJiggleTimer()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.jiggleMousePointer()
        }
        timer.tolerance = min(10, interval * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        mouseJiggleTimer = timer
    }

    func stopMouseJiggleTimer() {
        mouseJiggleTimer?.invalidate()
        mouseJiggleTimer = nil
        pendingMouseReturn?.cancel()
        pendingMouseReturn = nil
    }

    private func jiggleMousePointer() {
        guard isActive,
              !sessionPausedForScreenLock,
              AXIsProcessTrusted(),
              UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeMouseJiggleEnabled),
              let original = Self.currentMouseLocation(),
              let target = Self.mouseJiggleTarget(from: original)
        else {
            syncMouseJiggleTimer()
            return
        }

        guard Self.postMouseMove(to: target) else { return }

        pendingMouseReturn?.cancel()
        let returnMove = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingMouseReturn = nil
            guard self.isActive, !self.sessionPausedForScreenLock, AXIsProcessTrusted(),
                  UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeMouseJiggleEnabled) else {
                self.syncMouseJiggleTimer()
                return
            }
            guard let current = Self.currentMouseLocation() else { return }
            guard abs(current.x - target.x) <= 2,
                  abs(current.y - target.y) <= 2 else { return }
            _ = Self.postMouseMove(to: original)
        }
        pendingMouseReturn = returnMove
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: returnMove)
    }

    private static func currentMouseLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    private static func mouseJiggleTarget(from original: CGPoint) -> CGPoint? {
        guard let bounds = displayBounds(containing: original) else { return nil }
        let safeFrame = bounds.insetBy(dx: 2, dy: 2)
        let x = min(max(original.x, safeFrame.minX), safeFrame.maxX)
        let y = min(max(original.y, safeFrame.minY), safeFrame.maxY)

        if x + 1 <= safeFrame.maxX {
            return CGPoint(x: x + 1, y: y)
        }
        if x - 1 >= safeFrame.minX {
            return CGPoint(x: x - 1, y: y)
        }
        if y + 1 <= safeFrame.maxY {
            return CGPoint(x: x, y: y + 1)
        }
        if y - 1 >= safeFrame.minY {
            return CGPoint(x: x, y: y - 1)
        }
        return nil
    }

    private static func displayBounds(containing point: CGPoint) -> CGRect? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return nil
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            return nil
        }

        for display in displays.prefix(Int(count)) {
            let bounds = CGDisplayBounds(display)
            if point.x >= bounds.minX, point.x <= bounds.maxX,
               point.y >= bounds.minY, point.y <= bounds.maxY {
                return bounds
            }
        }
        return nil
    }

    private static func postMouseMove(to point: CGPoint) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: .mouseMoved,
                                  mouseCursorPosition: point,
                                  mouseButton: .left) else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }
}

