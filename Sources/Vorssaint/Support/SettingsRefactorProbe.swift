#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

enum SettingsRefactorProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier, identity.hasPrefix("com.vorssaint.tests."),
              let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        catch { fputs("Cannot create settings rendering directory: \(error)\n", stderr); exit(2) }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        defaults.register(defaults: Defaults.registeredDefaults)
        defaults.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        for feature in AppFeature.allCases {
            defaults.set(false, forKey: feature.availabilityKey)
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        defaults.set(false, forKey: DefaultsKey.windowLayoutShortcutsEnabled)
        defaults.set(false, forKey: DefaultsKey.volumeMixerEnabled)
        defaults.set(true, forKey: AppFeature.bluetoothSleep.availabilityKey)
        defaults.set(CommandLine.arguments.contains("--bluetooth-sleep-enabled"),
                     forKey: DefaultsKey.bluetoothSleepEnabled)
        if CommandLine.arguments.contains("--refactor-followup-only") {
            setPreviewAvailability(.notch, enabled: true)
            var failures = [String]()
            RefactorUtilityRenderingProbe.run(output: output, failures: &failures)
            SettingsFollowupRenderingProbe.run(output: output, failures: &failures)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--followup-only") {
            defaults.set(true, forKey: AppFeature.notch.availabilityKey)
            var failures = [String]()
            SettingsFollowupRenderingProbe.run(output: output, failures: &failures)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        let pages: [(String, AnyView)] = [
            ("mouse", AnyView(MouseSettings())),
            ("keyboard", AnyView(KeyboardSettings())),
            ("cleaning", AnyView(CleaningModeSettings())),
            ("audio-input", AnyView(AudioInputSettings())),
            ("data-permissions", AnyView(DataPermissionsSettings())),
            ("displays-disabled", AnyView(DisplaySettings().settingsSectionFocus(for: .energy))),
            ("bluetooth", AnyView(DisplaySettings(focus: .bluetoothSleep).settingsSectionFocus(for: .energy))),
            ("monitor-modules-off", AnyView(MonitorSettings())),
            ("dock", AnyView(DockSettings())),
            ("windows", AnyView(WindowLayoutSettings())),
            ("content-list", AnyView(NotchSettings(initialTab: .content))),
            ("indicators", AnyView(ScrollView {
                NotchSettings().activityPage.padding(22)
            }.toggleStyle(.switch))),
            ("content-timer", AnyView(NotchSettings(initialTab: .content, initialContent: .module(.timer)))),
            ("content-companion", AnyView(NotchSettings(initialTab: .content, initialContent: .companion))),
        ]
        var failures = [String]()
        for (name, view) in pages {
            if CommandLine.arguments.contains("--bluetooth-only"), name != "bluetooth" { continue }
            if name == "displays-disabled" { SettingsRouter.shared.request(AppFeature.brightness.settingsDestination) }
            if name == "bluetooth" { SettingsRouter.shared.request(AppFeature.bluetoothSleep.settingsDestination) }
            render(name, view: view, size: CGSize(width: 760, height: name == "data-permissions" ? 1400 : 838), output: output, failures: &failures)
        }
        for count in CommandLine.arguments.contains("--bluetooth-only") ? [] : [0, 30] {
            let sheet = AppListSheet(caption: SettingsAppListDescriptions.text(.enUS).dockPreview, centersContent: count == 0, onDone: {}) {
                if count == 0 {
                    ContentUnavailableView(SettingsAppListStrings.text(.enUS).disabledApps, systemImage: "app.dashed")
                } else {
                    LazyVStack {
                        ForEach(0..<count, id: \.self) { index in
                            Label("Example App \(index + 1)", systemImage: "app.fill")
                                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        }
                    }
                }
            } footer: { Button("Add app…") {} }
            let measured = NSHostingController(rootView: sheet).sizeThatFits(in: CGSize(width: 1000, height: 1000))
            if measured != CGSize(width: 520, height: 460) { failures.append("sheet size changes for \(count) apps: \(measured)") }
            render("app-list-\(count)", view: AnyView(sheet), size: CGSize(width: 520, height: 460), output: output, failures: &failures)
        }
        if !CommandLine.arguments.contains("--bluetooth-only") {
            InputSettingsRenderingProbe.run(output: output, failures: &failures)
            SettingsOwnershipRenderingProbe.run(output: output, failures: &failures)
        }
        defaults.removePersistentDomain(forName: identity)
        for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
        if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
        exit(failures.isEmpty ? 0 : 1)
    }

    static func setPreviewAvailability(_ feature: AppFeature, enabled: Bool) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.vorssaint.tests.") == true else { return }
        UserDefaults.standard.set(enabled, forKey: feature.availabilityKey)
    }

    static func render(_ name: String, view: AnyView, size: CGSize, output: URL, failures: inout [String]) {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading)
            .environment(\.controlActiveState, .active)
            .environment(\.settingsPermissionAccess, SettingsPermissionAccessors(
                verify: { _ in true }, request: { _, complete in complete(.granted) }))
            .preferredColorScheme(.light).background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        print("SETTINGS_RENDERING_PAGE \(name)")
        fflush(stdout)
        host.sizingOptions = []
        window.title = "Lattice Settings Rendering"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        host.layoutSubtreeIfNeeded()
        print("SETTINGS_RENDERING_GEOMETRY \(name) host=\(host.frame) visible=\(window.isVisible) occlusion=\(window.occlusionState.rawValue)")
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            failures.append("no bitmap for \(name)"); return
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            failures.append("no PNG for \(name)"); return
        }
        do { try data.write(to: output.appendingPathComponent(name + ".png")) }
        catch { failures.append("cannot save \(name): \(error)") }
    }
}
#endif
