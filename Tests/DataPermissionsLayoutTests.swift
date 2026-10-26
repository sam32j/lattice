// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI

enum DataPermissionsLayoutTests {
    static func run(_ suite: TestSuite) {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: DataSettingsCard {
            DataPermissionsRow(symbol: "square.and.arrow.down", title: "Import settings…",
                description: "Load settings from a file you exported earlier.", actionTitle: "Import…") {}
            DataSettingsDivider()
            DataPermissionsRow(symbol: "camera", title: "Camera", status: "Granted", tone: .granted,
                information: AnyView(Button {} label: { Image(systemName: "info.circle").frame(width: 22, height: 22) }),
                actionTitle: "Settings") {}
            DataSettingsDivider()
            DataPermissionsRow(symbol: "mic", title: "Microphone", status: "Not granted", tone: .missing,
                actionTitle: "Request", actionTone: .primary) {}
            DataSettingsDivider()
            DataPermissionsRow(symbol: "arrow.counterclockwise", title: "Clear all permissions",
                description: "Reset permissions and disable Launch at login. Your preference settings will not reset.",
                tone: .destructive, actionTitle: "Clear", actionTone: .destructive) {}
        }.padding(22).frame(width: 600))
        let window = NSWindow(contentRect: CGRect(x: -10_000, y: -10_000, width: 600, height: 360),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        let getter = NSSelectorFromString("accessibilityAttributeValue:")
        let setter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let prior = NSApp.perform(getter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
        NSApp.perform(setter, with: true, with: "AXEnhancedUserInterface")
        defer {
            NSApp.perform(setter, with: prior, with: "AXEnhancedUserInterface")
            window.orderOut(nil); window.contentView = nil; window.close()
        }
        window.orderFront(nil)
        window.makeFirstResponder(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        let frames = actionFrames(in: host)
        suite.expect(frames.count == 4, "data, permission, request and destructive rows each expose exactly one primary action")
        suite.expect(frames.allSatisfy { (90...112).contains($0.width) && (20...30).contains($0.height) },
                     "every row action uses compact native Settings sizing: \(frames)")
        if let first = frames.first {
            suite.expect(frames.allSatisfy { abs($0.width - first.width) < 1 && abs($0.height - first.height) < 1 },
                         "all row actions keep matching native sizes: \(frames)")
            suite.expect(frames.allSatisfy { abs($0.maxX - first.maxX) < 1 },
                         "the action column aligns across wrapping descriptions and permission status rows: \(frames)")
        }
    }

    private static func actionFrames(in element: AnyObject) -> [CGRect] {
        if element.accessibilityIdentifier?() == "data-permissions.action",
           element.accessibilityRole?() == .button, let frame = element.accessibilityFrame?() {
            return [frame]
        }
        return (element.accessibilityChildren?() ?? []).flatMap { actionFrames(in: $0 as AnyObject) }
    }
}
