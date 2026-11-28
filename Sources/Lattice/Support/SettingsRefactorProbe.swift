#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

enum SettingsRefactorProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier, identity.hasPrefix("io.github.sam32j.lattice.tests."),
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
        if CommandLine.arguments.contains("--upstream-344-only") {
            // The surfaces the v3.4.4 ports touched (ui-audit U1, U2, U3, U9,
            // U13, U32), each in English and German, light and dark, at the
            // Settings detail column's minimum width.
            var failures = [String]()
            FeatureRuntime.shared.setAvailable([.scrollInverter, .scrollHorizontal, .scrollSpeed, .smoothScroll,
                                                .switcher, .windowLayout, .screenRecorder, .notch], true)
            for key in [DefaultsKey.scrollHorizontalEnabled, DefaultsKey.scrollSpeedEnabled,
                        DefaultsKey.switcherEnabled, DefaultsKey.windowEdgeSnapEnabled,
                        DefaultsKey.windowEdgeSnapRestoreOnDrag, DefaultsKey.switcherIgnoreHoverSelection] {
                defaults.set(true, forKey: key)
            }
            // The sideways key matches speed's, so its picker shows the taken choice.
            defaults.set(ScrollHorizontalModifier.option.rawValue, forKey: DefaultsKey.scrollHorizontalModifier)
            var dimmable = BrightnessDisplay(id: 2, name: "Studio Monitor", isBuiltIn: false, method: .ddc,
                                             isActive: true, brightness: 0.5, readable: true)
            dimmable.canChooseDimming = true
            // Uninstaller results with some optional rows unchecked (U6).
            // PanelUninstallerView's .onDisappear resets AppUninstaller.shared,
            // so restage the sample immediately before each uninstaller render.
            func stageUninstallerSample() {
                MainActor.assumeIsolated {
                    let uninstaller = AppUninstaller.shared
                    uninstaller.target = AppUninstaller.Target(name: "Sample", bundleID: "com.example.sample",
                                                               url: URL(fileURLWithPath: "/Applications/Sample.app"),
                                                               icon: NSWorkspace.shared.icon(for: .applicationBundle))
                    func leftover(_ path: String, _ category: AppUninstaller.Category, _ size: Int64,
                                  _ match: UninstallerSupport.LeftoverMatch, include: Bool, _ inode: UInt64) -> AppUninstaller.Leftover {
                        AppUninstaller.Leftover(url: URL(fileURLWithPath: path), category: category, size: size,
                                                ownerBundleID: "com.example.sample", ownerGroupID: nil, evidenceBundleID: nil,
                                                confidence: match, fileIdentity: .init(device: 1, inode: inode), include: include)
                    }
                    uninstaller.items = [
                        leftover("/Applications/Sample.app", .app, 1_120_000_000, .exact, include: true, 1),
                        leftover(NSHomeDirectory() + "/Library/Application Support/Sample", .support, 815_000_000, .related, include: false, 2),
                        leftover(NSHomeDirectory() + "/Library/Application Support/com.example.sample", .support, 4_000, .exact, include: true, 3),
                        leftover(NSHomeDirectory() + "/Library/Caches/com.example.sample", .caches, 64_000_000, .exact, include: true, 4),
                    ]
                    uninstaller.phase = .results
                }
            }
            FeatureRuntime.shared.setAvailable([.uninstaller], true)
            let width: CGFloat = 560
            for language in [AppLanguage.enUS, .de] {
                L10n.shared.language = language
                for scheme in [ColorScheme.light, .dark] {
                    let suffix = "\(language.rawValue)-\(scheme == .dark ? "dark" : "light")"
                    let surfaces: [(String, AnyView, CGFloat)] = [
                        ("u1-mouse-scrolling", AnyView(MouseSettings().mouseScrollingCard.padding(20)), 1100),
                        ("u2-switcher", AnyView(ScrollView { SwitcherSettingsSection().padding(20) }), 1500),
                        ("u3-window-layout", AnyView(WindowLayoutSettings()), 1700),
                        ("u9-recorder", AnyView(ScreenRecorderSettings()), 1500),
                        ("u13-island-notifications", AnyView(VStack(alignment: .leading) {
                            NotchSettings().notificationsModuleOptions }.padding(20)), 200),
                        // The real row, inside the card's text inset, at the minimum width.
                        ("u32-dimming", AnyView(BrightnessDisplayRow(display: dimmable)
                            .padding(.leading, settingsRowTextInset).padding(20)), 110),
                    ]
                    for (name, view, height) in surfaces {
                        render("\(name)-\(suffix)", view: view, size: CGSize(width: width, height: height),
                               output: output, failures: &failures, colorScheme: scheme)
                    }
                    let uninstallerSurfaces: [(String, () -> AnyView, CGFloat)] = [
                        ("u6-uninstaller-settings", { AnyView(AppUninstallerTab()) }, 900),
                        ("u6-uninstaller-compact", { AnyView(PanelUninstallerView().frame(width: 388).padding(12)) }, 440),
                    ]
                    for (name, makeView, height) in uninstallerSurfaces {
                        stageUninstallerSample()
                        render("\(name)-\(suffix)", view: makeView(), size: CGSize(width: width, height: height),
                               output: output, failures: &failures, colorScheme: scheme)
                    }
                }
            }
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--upstream-345-only") {
            // The surfaces the v3.4.5 ports touched (ui-audit U4, U5, U7, U8,
            // U10, U11, U12, U14, U34), each in English and German, light and
            // dark, at the Settings detail column's minimum width.
            var failures = [String]()
            FeatureRuntime.shared.setAvailable([
                .windowLayout, .keepAwake, .notch, .notchAgents, .micMute, .mixer,
                .audioPriority, .monitorDisk, .monitorCPU, .fanControl,
            ], true)
            defaults.set(true, forKey: DefaultsKey.windowEdgeSnapEnabled)
            defaults.set(true, forKey: DefaultsKey.keepAwakeConnectedToPower)
            defaults.set(30, forKey: DefaultsKey.keepAwakePowerDisconnectDelay)
            defaults.set(true, forKey: DefaultsKey.notchEnabled)
            defaults.set(true, forKey: DefaultsKey.notchAgentsEnabled)
            defaults.set(true, forKey: DefaultsKey.microphoneLevelControlEnabled)
            defaults.set(true, forKey: DefaultsKey.audioPriorityInputEnabled)
            defaults.set(true, forKey: DefaultsKey.monitorAlertDisk)
            defaults.set(false, forKey: DefaultsKey.monitorAlertCPU)
            let width: CGFloat = 560
            for language in [AppLanguage.enUS, .de] {
                L10n.shared.language = language
                for scheme in [ColorScheme.light, .dark] {
                    let suffix = "\(language.rawValue)-\(scheme == .dark ? "dark" : "light")"
                    let surfaces: [(String, AnyView, CGFloat)] = [
                        ("u4-window-layout", AnyView(WindowLayoutSettings()), 1300),
                        ("u5-data-permissions", AnyView(DataPermissionsSettings()), 900),
                        ("u7-stay-awake", AnyView(StayAwakeSettings()), 1180),
                        ("u8-agents-settings", AnyView(ScrollView { NotchAgentsSettingsControls().padding(20) }), 760),
                        ("u10-u11-u34-audio-input", AnyView(ScrollView { AudioInputSettings().padding(20) }), 860),
                        ("u14-monitor-alerts", AnyView(ScrollView {
                            SettingsCard(title: FeatureStrings.monitorAlerts(language).section,
                                         caption: FeatureStrings.monitorAlerts(language).caption) {
                                MonitorAlertsControls()
                            }.padding(20)
                        }), 620),
                        ("u12-fan-control", AnyView(FanControlSection().frame(width: 388).padding(12)), 420),
                    ]
                    for (name, view, height) in surfaces {
                        render("\(name)-\(suffix)", view: view, size: CGSize(width: width, height: height),
                               output: output, failures: &failures, colorScheme: scheme)
                    }
                }
            }
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--stay-awake-only") {
            defaults.set(true, forKey: AppFeature.keepAwake.availabilityKey)
            var failures = [String]()
            for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                render("stay-awake-\(name)", view: AnyView(StayAwakeSettings()),
                       size: CGSize(width: 720, height: 1180), output: output, failures: &failures, colorScheme: scheme)
            }
            // The rows that unroll under a switch: the pointer interval and
            // the apps summary.
            defaults.set(true, forKey: DefaultsKey.keepAwakeMouseJiggleEnabled)
            defaults.set(true, forKey: DefaultsKey.keepAwakeRunningApps)
            render("stay-awake-expanded-light", view: AnyView(StayAwakeSettings()),
                   size: CGSize(width: 720, height: 1300), output: output, failures: &failures, colorScheme: .light)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--monitor-only") {
            var failures = [String]()
            FeatureRuntime.shared.setAvailable([.monitorCPU, .monitorMemory, .monitorNetwork], true)
            defaults.set(true, forKey: DefaultsKey.menuBarCPU)
            defaults.set(true, forKey: DefaultsKey.menuBarMemory)
            defaults.set(true, forKey: DefaultsKey.monitorAlertCPU)
            defaults.set(true, forKey: DefaultsKey.notchEnabled)
            FeatureRuntime.shared.setAvailable([.notch], true)
            for (name, view) in [("monitor", AnyView(MonitorSettings())),
                                 ("monitor-menu-bar", AnyView(MonitorMenuBarSettings()))] {
                render(name, view: view, size: CGSize(width: 720, height: 900), output: output,
                       failures: &failures, colorScheme: .light)
            }
            defaults.set("bars", forKey: DefaultsKey.menuBarMetricAppearance)
            render("monitor-menu-bar-bars", view: AnyView(MonitorMenuBarSettings()),
                   size: CGSize(width: 720, height: 900), output: output, failures: &failures, colorScheme: .light)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--app-manager-only") {
            var failures = [String]()
            MainActor.assumeIsolated { AppManagerModules.setOn(true) }
            for tab in AppManagerTab.allCases {
                MainActor.assumeIsolated { AppManagerSettings.lastTab = tab }
                for scheme in [ColorScheme.light, .dark] {
                    render("app-manager-\(tab.rawValue)-\(scheme == .dark ? "dark" : "light")",
                           view: AnyView(AppManagerSettings()), size: CGSize(width: 720, height: 900),
                           output: output, failures: &failures, colorScheme: scheme)
                }
            }
            render("app-manager-glyphs", view: AnyView(VStack(spacing: 18) {
                       ForEach([20.0, 48.0], id: \.self) { size in
                           HStack(spacing: size) {
                               ForEach(["tray", LatticeSymbol.videoDownloaderSymbol, LatticeSymbol.mediaSymbol, "rectangle.compress.vertical", "text.append",
                                        "waveform.path.ecg", LatticeSymbol.appManagerSymbol, "cpu"],
                                       id: \.self) { LatticeSymbol($0).font(.system(size: size, weight: .medium)) }
                           }
                       }
                   }.padding(20)),
                   size: CGSize(width: 700, height: 160), output: output, failures: &failures, colorScheme: .light)
            MainActor.assumeIsolated { AppManagerPanelState.shared.tab = .updates }
            render("app-manager-panel", view: AnyView(
                       LatticeHubHostedUtility(item: .appManager, notchSize: CGSize(width: 388, height: 420)) {}
                           .frame(width: 388, height: 420).padding(12).background(Color.black)),
                   size: CGSize(width: 412, height: 444), output: output, failures: &failures, colorScheme: .dark)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--island-settings-only") {
            var failures = [String]()
            NotchSettingsRenderingProbe.run(output: output, failures: &failures)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--data-permissions-only") {
            var failures = [String]()
            DataPermissionsRenderingProbe.run(output: output, failures: &failures)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--video-downloader-only") {
            var failures = [String]()
            VideoDownloaderRenderingProbe.run(output: output, failures: &failures)
            defaults.removePersistentDomain(forName: identity)
            for failure in failures { print("SETTINGS_RENDERING_FAILED \(failure)") }
            if failures.isEmpty { print("SETTINGS_RENDERING_OK output=\(output.path)") }
            exit(failures.isEmpty ? 0 : 1)
        }
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
            ("audio", AnyView(AudioSettings())),
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
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else { return }
        UserDefaults.standard.set(enabled, forKey: feature.availabilityKey)
    }

    static func render(_ name: String, view: AnyView, size: CGSize, output: URL, failures: inout [String],
                       colorScheme: ColorScheme = .light) {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading)
            .environment(\.controlActiveState, .active)
            .environment(\.settingsPermissionAccess, SettingsPermissionAccessors(
                verify: { _ in true }, request: { _, complete in complete(.granted) }))
            .preferredColorScheme(colorScheme).background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.appearance = appearance
        host.appearance = appearance
        print("SETTINGS_RENDERING_APPEARANCE \(name) window=\(window.effectiveAppearance.name.rawValue) host=\(host.effectiveAppearance.name.rawValue)")
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
