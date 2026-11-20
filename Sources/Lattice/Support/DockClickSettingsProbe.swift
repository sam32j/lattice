#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

enum DockClickSettingsProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
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
        let copy = DockClickCopy.strings(.enUS)
        let labels = [copy.toggleWindows, copy.hideApps, copy.cycleWindows]
        settle()
        if labels.contains(where: { findButton($0, in: host) != nil }) {
            failures.append("Dock tiles should be hidden while the Dock Tile Action toggle is off.")
        }
        guard let toggle = findToggle(copy.title, in: host) else {
            failures.append("Missing Dock Tile Action toggle.")
            return
        }
        _ = toggle.accessibilityPerformPress?()
        settle()
        if keys.map({ defaults.bool(forKey: $0) }) != [true, false, false] {
            failures.append("Enabling Dock Tile Action must default to Toggle Windows.")
        }
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
        _ = findToggle(copy.title, in: host)?.accessibilityPerformPress?()
        settle()
        if keys.contains(where: { defaults.bool(forKey: $0) }) {
            failures.append("Turning off Dock Tile Action must clear every Dock Click action.")
        }
        granted = false
        // A revoked grant can precede the persisted activation being cleared.
        defaults.set(true, forKey: DefaultsKey.dockClickMinimize)
        settle()
        _ = findToggle(copy.title, in: host)?.accessibilityPerformPress?()
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

    private static func findToggle(_ label: String, in element: AnyObject) -> AnyObject? {
        if element.accessibilityRole?() == .checkBox, element.accessibilityLabel?() == label { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let toggle = findToggle(label, in: child as AnyObject) { return toggle }
        }
        return nil
    }
}
#endif
