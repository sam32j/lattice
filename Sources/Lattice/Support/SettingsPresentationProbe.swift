#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Layout-only development host. It refuses real application identities and
/// bypasses normal startup, recovery, and feature installation entirely.
enum SettingsPresentationProbe {
    private final class Delegate: NSObject, NSApplicationDelegate {
        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    }
    private static let delegate = Delegate()
    private static var window: SettingsWindow?

    static func runAndExit() -> Never {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            fputs("Settings preview requires an isolated test bundle identifier.\n", stderr)
            exit(2)
        }
        let defaults = UserDefaults.standard
        defaults.register(defaults: Defaults.registeredDefaults)
        for feature in AppFeature.allCases {
            defaults.set(true, forKey: feature.availabilityKey)
            // `--features-on` previews pages with every feature switched on.
            let on = CommandLine.arguments.contains("--features-on")
            for key in feature.enabledKeys { defaults.set(on, forKey: key) }
        }
        defaults.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        // `--shortcuts` opens on the long Keyboard Shortcuts page (scroll-edge
        // checks), `--dock` on Dock & Applications, `--audio` on Audio (with
        // `--audio-output`, landing on its Output segment through a deep link).
        let arguments = CommandLine.arguments
        SettingsRouter.shared.page = arguments.contains("--shortcuts") ? .shortcuts
            : arguments.contains("--dock") ? .dock
            : arguments.contains("--audio") ? .audio : .features
        if arguments.contains("--audio-output") {
            SettingsRouter.shared.request(AppFeature.mixer.settingsDestination)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        // `--dark` previews the window in dark mode whatever the Mac is set to.
        if CommandLine.arguments.contains("--dark") { app.appearance = NSAppearance(named: .darkAqua) }
        let host = SettingsHostingController(rootView: SettingsView())
        host.sizingOptions = []
        let window = SettingsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.configureGeometry(for: host.view)
        window.setContentSize(NSSize(width: 772, height: 838))
        window.title = "Lattice Settings Preview"
        window.isReleasedWhenClosed = false
        window.center()
        Self.window = window
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            func splitView(in view: NSView) -> NSSplitView? {
                if let split = view as? NSSplitView { return split }
                return view.subviews.lazy.compactMap { splitView(in: $0) }.first
            }
            if let split = splitView(in: host.view),
               let controller = split.delegate as? NSSplitViewController,
               let sidebar = controller.splitViewItems.first {
                print("SETTINGS_GEOMETRY content=\(host.view.frame.width) sidebar=\(split.subviews.first?.frame.width ?? 0) collapsible=\(sidebar.canCollapse)")
            }
        }
        app.activate(ignoringOtherApps: true)
        print("SETTINGS_PREVIEW_READY")
        app.run()
        exit(0)
    }
}
#endif
