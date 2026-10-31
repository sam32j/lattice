#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Isolated page shells and fixture data only. Normal startup is bypassed.
enum FeaturePageMigrationRenderingProbe {
    private final class ConstructionCount { var value = 0 }
    private struct Marker: View {
        init(_ count: ConstructionCount) { count.value += 1 }
        var body: some View { Text("Utility viewport") }
    }

    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Feature page rendering requires an isolated test identity.")
            return
        }
        for feature in AppFeature.migratedPageFeatures.sorted(by: { $0.rawValue < $1.rawValue }) {
            let count = ConstructionCount()
            let view = FeatureActivationPage(feature: feature) { Marker(count) }
            SettingsRefactorProbe.render("activation-off-" + feature.rawValue, view: AnyView(view),
                size: CGSize(width: 540, height: 528), output: output, failures: &failures)
            if count.value != 0 { failures.append("Disabled \(feature) constructed content.") }
        }
        for feature in [AppFeature.keepAwake, .killProcess, .commandBar] {
            SettingsRouter.shared.request(feature.settingsDestination)
            SettingsRefactorProbe.render("sidebar-off-" + feature.rawValue, view: AnyView(SettingsView()),
                size: CGSize(width: 772, height: 528), output: output, failures: &failures)
        }
        SettingsRefactorProbe.setPreviewAvailability(.killProcess, enabled: true)
        let fixture = NavigationStack {
            FeatureActivationPage(feature: .killProcess) {
                VStack {
                    HStack { Text("Processes").font(.headline); Spacer(); Text("24 processes") }
                    List(0..<24, id: \.self) { index in
                        HStack { Text("Example process \(index + 1)"); Spacer(); Text("12 MB") }
                    }
                }
                .padding(16)
            }
        }
        SettingsRefactorProbe.render("activation-on-utility", view: AnyView(fixture),
            size: CGSize(width: 540, height: 528), output: output, failures: &failures)
        renderToolbarWindow(AnyView(fixture), output: output, failures: &failures)
        SettingsRefactorProbe.setPreviewAvailability(.killProcess, enabled: false)

        let updates = AppUpdatesService.shared
        updates.hasCheckedThisSession = true
        updates.items = (0..<18).map { index in
            AppUpdatesSupport.Item(id: "fixture.\(index)", source: .packageManager,
                name: "Example app \(index + 1)", installedVersion: "1.0", latestVersion: "2.0",
                token: "example-\(index)", bundlePath: nil, storePage: nil,
                bundleID: "example.fixture.\(index)")
        }
        SettingsRefactorProbe.render("app-updates-overflow", view: AnyView(
            ScrollView { AppUpdatesListView().padding(16) }),
            size: CGSize(width: 540, height: 528), output: output, failures: &failures)
        updates.items = []
        updates.lastCheck = Date() // Keep the fixture page from starting a real scan on appearance.
        for feature in [AppFeature.cleaner, .appUpdates] {
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: true)
            for dark in [false, true] {
                renderSettingsToolbarWindow(feature: feature, dark: dark, output: output, failures: &failures)
            }
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: false)
        }
    }
    private static func renderToolbarWindow(_ content: AnyView, output: URL, failures: inout [String]) {
        let host = SettingsHostingController(rootView: content)
        host.sizingOptions = []
        let window = SettingsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 772, height: 528))
        window.title = "Utility activation fixture"
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        host.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        let toolbarItems = window.toolbar?.items ?? []
        print("FEATURE_ACTIVATION_TOOLBAR items=\(toolbarItems.count) labels=\(toolbarItems.map(\.label))")
        if toolbarItems.isEmpty { failures.append("Active utility has no toolbar controls.") }
        guard let frame = window.contentView?.superview,
              let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
            failures.append("Cannot capture the native toolbar window.")
            return
        }
        frame.cacheDisplay(in: frame.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        do { try png.write(to: output.appendingPathComponent("activation-native-toolbar.png")) }
        catch { failures.append("Cannot save native toolbar: \(error)") }
    }

    private static func renderSettingsToolbarWindow(feature: AppFeature, dark: Bool, output: URL, failures: inout [String]) {
        SettingsRouter.shared.request(feature.settingsDestination)
        let host = SettingsHostingController(rootView: SettingsView()
            .preferredColorScheme(dark ? .dark : .light))
        host.sizingOptions = []
        let window = SettingsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .resizable]
        window.configureGeometry(for: host.view)
        window.setContentSize(NSSize(width: 772, height: 838))
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.view.layoutSubtreeIfNeeded()
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        let items = window.toolbar?.items ?? []
        let title = SettingsOwnershipStrings.enable(feature.hubTitle(L10n.shared.s,
            hub: FeatureStrings.hub(.enUS)), .enUS)
        let activationID = "feature-activation-\(feature.rawValue)"
        let activation = items.first { $0.itemIdentifier.rawValue.contains(activationID) || $0.label == title }
        if let view = activation?.view {
            let frame = view.convert(view.bounds, to: nil)
            print("SETTINGS_ACTIVATION_CONTROL feature=\(feature) dark=\(dark) frame=\(frame) window=\(window.frame.size)")
            if frame.maxX < 772 - 48 { failures.append("Activation control is not at the toolbar trailing edge.") }
        } else {
            failures.append("Settings window has no activation control.")
        }
        guard let frame = window.contentView?.superview,
              let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
            failures.append("Cannot capture the Settings toolbar."); return
        }
        frame.cacheDisplay(in: frame.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            failures.append("Cannot encode the Settings toolbar."); return
        }
        do { try data.write(to: output.appendingPathComponent("settings-toolbar-\(feature.rawValue)-\(dark ? "dark" : "light").png")) }
        catch { failures.append("Cannot save Settings toolbar: \(error)") }
        let chrome = NSRect(x: 0, y: frame.isFlipped ? 0 : frame.bounds.height - 64,
                            width: frame.bounds.width, height: 64)
        if let chromeBitmap = frame.bitmapImageRepForCachingDisplay(in: chrome) {
            frame.cacheDisplay(in: chrome, to: chromeBitmap)
            if let chromeData = chromeBitmap.representation(using: .png, properties: [:]) {
                do { try chromeData.write(to: output.appendingPathComponent(
                    "settings-toolbar-\(feature.rawValue)-\(dark ? "dark" : "light")-chrome.png")) }
                catch { failures.append("Cannot save toolbar chrome: \(error)") }
            }
        }
    }

}
#endif
