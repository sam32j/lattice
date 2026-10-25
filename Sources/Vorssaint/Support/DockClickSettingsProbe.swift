#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

enum DockClickSettingsProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.vorssaint.tests.") == true else {
            failures.append("Dock tile checks require an isolated bundle."); return
        }
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.dockClickMinimize, DefaultsKey.dockClickHide, DefaultsKey.dockClickCycleWindows]
        keys.forEach { defaults.set(false, forKey: $0) }
        var granted = true
        var requests = 0
        let access = SettingsPermissionAccessors(verify: { _ in granted }, request: { _, reply in
            requests += 1; reply(.denied)
        })
        // The real tile/permission flow runs, but never starts an input tap.
        let view = DockClickSettings(sync: {}).environment(\.settingsPermissionAccess, access)
        let host = NSHostingView(rootView: view.padding(22))
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 760, height: 220),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        let getter = NSSelectorFromString("accessibilityAttributeValue:")
        let setter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let prior = NSApp.perform(getter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
        NSApp.perform(setter, with: true, with: "AXEnhancedUserInterface")
        defer {
            NSApp.perform(setter, with: prior, with: "AXEnhancedUserInterface")
            window.orderOut(nil); window.contentView = nil; window.close()
            keys.forEach { defaults.set(false, forKey: $0) }
        }
        func settle() {
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            host.layoutSubtreeIfNeeded()
        }
        let labels = ["Toggle Windows", "Hide/Unhide Apps", "Cycle Windows"]
        settle()
        for (index, label) in labels.enumerated() {
            guard let button = findButton(label, in: host) else {
                failures.append("Missing Dock tile: \(label)"); continue
            }
            _ = button.accessibilityPerformPress?()
            settle()
            if keys.map({ defaults.bool(forKey: $0) }) != (0..<3).map({ $0 == index }) {
                failures.append("Dock tile \(label) did not exclusively select its action.")
            }
        }
        _ = findButton("Cycle Windows", in: host)?.accessibilityPerformPress?()
        settle()
        if keys.contains(where: { defaults.bool(forKey: $0) }) {
            failures.append("Clicking the selected Dock tile must allow all actions off.")
        }
        granted = false
        // A revoked grant can precede the persisted activation being cleared.
        defaults.set(true, forKey: DefaultsKey.dockClickMinimize)
        settle()
        _ = findButton("Toggle Windows", in: host)?.accessibilityPerformPress?()
        settle()
        if requests != 1 || keys.contains(where: { defaults.bool(forKey: $0) }) {
            failures.append("Denied Dock permission must leave every tile off.")
        }
        defaults.set(true, forKey: DefaultsKey.dockClickCycleWindows)
        SettingsRefactorProbe.render("dock-click-tiles-selected", view: AnyView(DockClickSettings(sync: {}).padding(22)),
            size: CGSize(width: 760, height: 220), output: output, failures: &failures)
    }

    private static func findButton(_ label: String, in element: AnyObject) -> AnyObject? {
        if element.accessibilityRole?() == .button, element.accessibilityLabel?() == label { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let button = findButton(label, in: child as AnyObject) { return button }
        }
        return nil
    }
}
#endif
