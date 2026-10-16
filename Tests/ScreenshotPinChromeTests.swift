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
            let glass = children.flatMap { descendants(in: $0.contentView) }.filter { NSStringFromClass(type(of: $0)) == "NSGlassEffectView" }
            suite.expect(glass.count == 3 && glass.allSatisfy { $0.value(forKey: "effectIsInteractive") as? Bool == false },
                         "native glass disables press highlight while preserving distortion")
            suite.expect(glass.count == 3 && glass.allSatisfy { ($0.value(forKey: "_contentLensing") as? Int) == 1 },
                         "native glass enables liquid content lensing distortion")
            suite.expect(glass.count == 3 && glass.allSatisfy { $0.value(forKey: "tintColor") is NSColor },
                         "native glass applies subtle dark tint for icon legibility")
        }
        suite.expect(buttons.count == 3 && buttons.allSatisfy { button in
            guard let root = button.window?.contentView else { return false }
            let target = button.convert(button.bounds, to: root).insetBy(dx: -8, dy: -8)
            return root.bounds.contains(target)
        }, "circular glass controls have transparent room around every edge to prevent clipping")
        suite.expect(buttons.count == 3 && buttons.allSatisfy { button in
            guard let cell = button.cell else { return false }
            let icon = cell.imageRect(forBounds: button.bounds)
            let cursor = button.accessibilityLabel() == ScreenshotPinStrings.localized(L10n.shared.language).clickThrough
            let offset: CGFloat = cursor ? 2 / (button.window?.backingScaleFactor ?? 1) : 0
            return abs(icon.midX - button.bounds.midX - offset) < 0.01
                && abs(icon.midY - button.bounds.midY) < 0.01
        }, "control symbols are centered with the cursor's two-pixel optical adjustment")
        for button in buttons {
            guard let window = button.window else { continue }
            let centerInWindow = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
            let hit = window.contentView?.hitTest(centerInWindow)
            suite.expect(hit === button, "hit testing center of button returns the button, got: \(String(describing: hit))")
        }
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

        // Test temporary drag hide
        let pin2 = ScreenshotPinWindow(image: image, scale: 2)
        pin2.showPin()
        defer { pin2.closePin() }
        suite.expect(pin2.isVisible, "pin2 is initially visible")
        pin2.setHiddenForDrag(true)
        suite.expect(!pin2.isVisible, "setHiddenForDrag(true) temporarily hides the pin window")
        suite.expect(pin2.isHiddenForDrag, "pin2 records hidden-for-drag state")
        pin2.setHiddenForDrag(false)
        suite.expect(pin2.isVisible, "setHiddenForDrag(false) restores pin visibility")
        suite.expect(!pin2.isHiddenForDrag, "pin2 is no longer in hidden-for-drag state")
    }

    private static func buttons(in view: NSView?) -> [NSButton] {
        guard let view else { return [] }
        return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }

    private static func descendants(in view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants(in: $0) }
    }
}
