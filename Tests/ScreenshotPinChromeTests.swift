// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotPinChromeTests {
    @MainActor static func run(_ suite: TestSuite, image: CGImage) {
        let pin = ScreenshotPinWindow(image: image, scale: 2)
        pin.showPin()
        defer { pin.closePin() }
        pin.updateHover(at: CGPoint(x: pin.frame.midX, y: pin.frame.midY))
        let children = pin.childWindows ?? []
        suite.expect(children.count == 4 && children.allSatisfy(\.isVisible),
                     "showing a pin attaches its three control surfaces and feedback surface")
        let controls = children.filter { !$0.ignoresMouseEvents }
        suite.expect(controls.count == 3, "only control surfaces receive clicks; feedback passes them through")
        let initialOrigins = children.map { $0.frame.origin }
        pin.setFrameOrigin(CGPoint(x: pin.frame.minX + 20, y: pin.frame.minY + 10))
        suite.expect(zip(initialOrigins, children).allSatisfy { origin, child in
            abs(child.frame.minX - origin.x - 20) < 1 && abs(child.frame.minY - origin.y - 10) < 1
        }, "all child surfaces track pin movement without drifting")
        let buttons = children.flatMap { buttons(in: $0.contentView) }
        suite.expect(buttons.count == 3 && buttons.allSatisfy { button in
            guard let cell = button.cell as? NSButtonCell else { return false }
            return cell.highlightsBy.isEmpty && cell.showsStateBy.isEmpty
        }, "pressing a pin button does not recolor or displace its symbol")
        if #available(macOS 27.0, *) {
            let glass = children.flatMap { $0.contentView?.subviews ?? [] }.compactMap { $0 as? NSGlassEffectView }
            suite.expect(glass.count == 3 && glass.allSatisfy { !$0.effectIsInteractive },
                         "glass circles retain their backdrop without an obscuring interactive press highlight")
        }
        suite.expect(buttons.count == 3 && buttons.allSatisfy { button in
            guard let root = button.window?.contentView else { return false }
            let target = button.convert(button.bounds, to: root).insetBy(dx: -8, dy: -8)
            return root.bounds.contains(target)
        }, "circular glass controls have transparent room around every edge to prevent clipping")
        suite.expect(buttons.count == 3 && buttons.allSatisfy { button in
            guard let cell = button.cell else { return false }
            let icon = cell.imageRect(forBounds: button.bounds)
            return abs(icon.midX - button.bounds.midX) < 0.01
                && abs(icon.midY - button.bounds.midY) < 0.01
        }, "close, lock and cursor symbols are centered in their circular hit targets")
        let strings = ScreenshotPinStrings.localized(L10n.shared.language)
        let cursor = buttons.first { $0.accessibilityLabel() == strings.clickThrough }
        cursor?.performClick(nil)
        suite.expect(cursor != nil && pin.ignoresMouseEvents && controls.allSatisfy { !$0.ignoresMouseEvents },
                     "cursor button enables image click-through while controls stay interactive")
        cursor?.performClick(nil)
        suite.expect(!pin.ignoresMouseEvents, "the same cursor button turns click-through off")
        buttons.first { $0.accessibilityLabel() == strings.lock }?.performClick(nil)
        suite.expect(pin.isPositionLocked, "the visible lock button locks position and dimensions")
        buttons.first { $0.accessibilityLabel() == L10n.shared.s.menuClose }?.performClick(nil)
        suite.expect(pin.isClosed && (pin.childWindows ?? []).isEmpty && children.allSatisfy { !$0.isVisible },
                     "the visible close button detaches and hides every child surface")
    }

    private static func buttons(in view: NSView?) -> [NSButton] {
        guard let view else { return [] }
        return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }
}
