#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Disabled real Settings pages only. No workspace service is activated.
enum WorkspaceEmptyStateProbe {
    private static let features: [AppFeature] = [
        .mediaTools, .cleaner, .uninstaller, .homebrew, .appUpdates, .killProcess, .portManager,
    ]

    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Workspace previews require an isolated identity.")
            return
        }
        for feature in features {
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: false)
            for height in [CGFloat(528), 838] {
                render(feature, height: height, dark: false, output: output, failures: &failures)
            }
        }
        render(.appUpdates, height: 838, dark: true, output: output, failures: &failures)
    }

    private static func render(_ feature: AppFeature, height: CGFloat, dark: Bool,
                               output: URL, failures: inout [String]) {
        SettingsRouter.shared.request(feature.settingsDestination)
        let host = SettingsHostingController(rootView: SettingsView()
            .preferredColorScheme(dark ? .dark : .light))
        host.sizingOptions = []
        let window = SettingsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .resizable]
        window.configureGeometry(for: host.view)
        window.setContentSize(NSSize(width: 772, height: height))
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.view.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        defer { window.orderOut(nil); window.contentView = nil; window.close() }

        let items = window.toolbar?.items ?? []
        let title = SettingsOwnershipStrings.enable(feature.hubTitle(L10n.shared.s,
            hub: FeatureStrings.hub(.enUS)), .enUS)
        let activationID = "feature-activation-\(feature.rawValue)"
        if !items.contains(where: { $0.itemIdentifier.rawValue.contains(activationID) || $0.label == title }) {
            failures.append("Disabled \(feature) has no toolbar switch.")
        }
        if let switchIndex = items.firstIndex(where: {
            $0.itemIdentifier.rawValue.contains(activationID) || $0.label == title
        }), items.count - switchIndex - 1 != 0 {
            failures.append("Disabled \(feature) still exposes an options button.")
        }
        print("WORKSPACE_OFF_TOOLBAR feature=\(feature) height=\(height) labels=\(items.map(\.label))")
        guard let frame = window.contentView?.superview,
              let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
            failures.append("Cannot capture \(feature)."); return
        }
        frame.cacheDisplay(in: frame.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            failures.append("Cannot encode \(feature)."); return
        }
        do { try data.write(to: output.appendingPathComponent(
            "workspace-off-\(feature.rawValue)-\(Int(height))-\(dark ? "dark" : "light").png")) }
        catch { failures.append("Cannot save \(feature): \(error)") }
    }
}
#endif
