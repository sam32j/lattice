// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

/// Exercise the shared Dock/Switcher image boundary without reading any real
/// app's preferences, bundle resources or authorization state.
enum SystemAppIconTests {
    static func run(_ suite: TestSuite) {
        let pid: pid_t = 12345
        let source = NSImage(size: CGSize(width: 32, height: 32))
        source.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 32, height: 32).fill()
        source.unlockFocus()
        var lookups: [pid_t] = []
        func systemIcon(_ value: pid_t) -> NSImage? {
            lookups.append(value)
            return source
        }
        SwitcherAppIconCache.beginSession()
        defer { SwitcherAppIconCache.endSession() }
        let first = SwitcherAppIconCache.icon(for: pid, systemIcon: systemIcon)
        suite.expect(first?.size == source.size && lookups == [pid],
                     "Dock and Switcher resolve the requested app through the system icon boundary")
        let repeated = SwitcherAppIconCache.icon(for: pid, systemIcon: systemIcon)
        suite.expect(first === repeated && lookups == [pid],
                     "a Switcher session reuses the resolved system icon")
        suite.expect(first?.tiffRepresentation != nil,
                     "the system-provided icon remains drawable after appearance wrapping")
        SwitcherAppIconCache.endSession()
        let fresh = SwitcherAppIconCache.icon(for: pid, systemIcon: systemIcon)
        let next = SwitcherAppIconCache.icon(for: pid, systemIcon: systemIcon)
        suite.expect(fresh != nil && next != nil && fresh !== next && lookups == [pid, pid, pid],
                     "Dock lookups outside a session refresh system icons rather than retaining old choices")
        suite.expect(SwitcherAppIconCache.icon(for: pid, systemIcon: { _ in nil }) == nil,
                     "a missing system icon returns no fabricated image or custom-resource fallback")
        suite.expect(SwitcherAppIconCache.icon(for: pid_t.max) == nil,
                     "a nonexistent process has no icon and never opens target preferences")
    }
}
