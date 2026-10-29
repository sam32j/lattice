import AppKit
import SwiftUI

enum SettingsShortcutConsumerTests {
    class State {
        let defaults: UserDefaults
        init(_ defaults: UserDefaults) { self.defaults = defaults }
    }
    final class MarkerView: NSView {}
    struct Marker: NSViewRepresentable {
        func makeNSView(context: Context) -> MarkerView { MarkerView() }
        func updateNSView(_ view: MarkerView, context: Context) {}
    }

    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.shortcut-consumer.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let role = GlobalShortcutRole.clipboard
        defaults.set(true, forKey: role.feature.availabilityKey)
        for key in role.requiredEnableKeys { defaults.set(true, forKey: key) }
        defaults.set("", forKey: role.storageKey)
        let catalog = Catalog(defaults), group = GroupStatus(defaults)
        let inventory = Inventory(defaults)
        let utilityRoles: [(GlobalShortcutRole, String)] = [
            (.clipboard, DefaultsKey.clipboardHistoryEnabled), (.shelf, DefaultsKey.shelfEnabled),
            (.cameraPreview, AppFeature.cameraPreview.availabilityKey),
            (.quickLauncher, AppFeature.quickLauncher.availabilityKey),
            (.scratchpad, AppFeature.scratchpad.availabilityKey)
        ]
        for (utility, enableKey) in utilityRoles {
            defaults.set(utility.defaultShortcut.storageValue, forKey: utility.storageKey)
            defaults.set(true, forKey: utility.requiredEnableKeys.last!)
            defaults.set(false, forKey: enableKey)
            suite.expect(!inventory.availableRoles.contains(utility),
                         "\(utility) is hidden on Keyboard Shortcuts while its page toggle is off, even with a configured shortcut")
            defaults.set(true, forKey: enableKey)
            suite.expect(inventory.availableRoles.contains(utility),
                         "\(utility) returns to Keyboard Shortcuts when its page toggle is on")
        }
        defaults.set("", forKey: role.storageKey)
        defaults.set(true, forKey: DefaultsKey.clipboardHistoryEnabled)
        defaults.set(false, forKey: DefaultsKey.pastePlainEnabled)
        defaults.set("", forKey: GlobalShortcutRole.pastePlain.storageKey)
        suite.expect(inventory.availableRoles.contains(.pastePlain),
                     "the central editor retains disabled and cleared Plain Paste while Clipboard History is installed")
        defaults.set(false, forKey: DefaultsKey.clipboardHistoryEnabled)
        suite.expect(!inventory.availableRoles.contains(.pastePlain),
                     "Plain Paste leaves the central editor when its Clipboard History owner is uninstalled")
        defaults.set(true, forKey: DefaultsKey.clipboardHistoryEnabled)
        suite.expect(catalog.roleShortcut(role) == nil,
                     "the Command Bar hint consumer hide cleared shortcuts even when enable keys stay on")
        suite.expect(!group.featureHasActiveShortcut(role.feature, roles: [role]),
                     "the actual disclosure header agrees with inactive cleared rows")
        defaults.set(role.defaultShortcut.storageValue, forKey: role.storageKey)
        suite.expect(catalog.roleShortcut(role) == role.defaultShortcut,
                     "the Command Bar shows a valid enabled shortcut")
        suite.expect(group.featureHasActiveShortcut(role.feature, roles: [role]),
                     "a valid enabled shortcut makes its disclosure group active")
        for key in role.requiredEnableKeys { defaults.set(false, forKey: key) }
        suite.expect(catalog.roleShortcut(role) == nil,
                     "validity checks preserve the existing enable-key gates")
        MainActor.assumeIsolated {
            defaults.set("", forKey: GlobalShortcutRole.quickLauncher.storageKey)
            suite.expect(!rendersLauncherHint(defaults),
                         "the actual launcher footer renders no shortcut label for a cleared assignment")
            defaults.set(GlobalShortcutRole.quickLauncher.defaultShortcut.storageValue,
                         forKey: GlobalShortcutRole.quickLauncher.storageKey)
            suite.expect(rendersLauncherHint(defaults), "the launcher footer still renders a valid shortcut")
        }
    }

    @MainActor private static func rendersLauncherHint(_ defaults: UserDefaults) -> Bool {
        let host = NSHostingView(rootView: Launcher(defaults: defaults).frame(width: 300, height: 40))
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 300, height: 40),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        window.orderFront(nil)
        let deadline = Date().addingTimeInterval(0.15)
        while Date() < deadline {
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        func hasMarker(_ view: NSView) -> Bool {
            view is MarkerView || view.subviews.contains(where: hasMarker)
        }
        return hasMarker(host)
    }
}
