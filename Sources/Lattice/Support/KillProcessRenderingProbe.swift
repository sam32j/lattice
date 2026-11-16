// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Renders the Kill Process list on each surface from a live process
/// snapshot, in light and dark appearance. Runs before normal startup under
/// an isolated test identity: `--kill-process-rendering --output-directory DIR`.
enum KillProcessRenderingProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier,
              identity.hasPrefix("io.github.sam32j.lattice.tests."),
              let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        defaults.register(defaults: Defaults.registeredDefaults)
        defaults.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        SettingsRefactorProbe.setPreviewAvailability(.killProcess, enabled: true)
        defaults.set(KillProcessScope.everything.rawValue, forKey: DefaultsKey.killProcessScopeIsland)

        let service = KillProcessService.shared
        service.refresh(force: true)
        let deadline = Date().addingTimeInterval(8)
        while !service.hasLoadedOnce && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        var failures: [String] = []
        if !service.hasLoadedOnce { failures.append("no process snapshot") }
        print("KILL_PROCESS_RENDERING items=\(service.items.count)")
        if CommandLine.arguments.contains("--dump") {
            for item in service.items where item.scope != .apps {
                print("KP_ITEM \(item.kind) bundle=\(item.bundleIdentifier ?? "-") helpers=\(item.helpers.count) \(item.path)")
            }
        }
        for dark in [false, true] {
            let scheme: ColorScheme = dark ? .dark : .light
            let suffix = dark ? "-dark" : "-light"
            let withHelpers = Set(service.items.filter { $0.scope == .apps && $0.helpers.count > 6 }
                .prefix(1).map(\.pid))
            SettingsRefactorProbe.render("settings" + suffix, view: AnyView(KillProcessView(surface: .settings,
                                                                                            expandedPIDs: withHelpers)),
                size: CGSize(width: 540, height: 600), output: output, failures: &failures, colorScheme: scheme)
            SettingsRefactorProbe.render("hud" + suffix, view: AnyView(
                KillProcessView(surface: .hud).padding(16)
                    .background { HUDBackdrop(cornerRadius: 22, contrast: .standard) }),
                size: CGSize(width: 420, height: 520), output: output, failures: &failures, colorScheme: scheme)
        }
        defaults.set(KillProcessScope.everything.rawValue, forKey: DefaultsKey.killProcessScopeSettings)
        let started = Date()
        SettingsRefactorProbe.render("settings-everything", view: AnyView(KillProcessView(surface: .settings)),
            size: CGSize(width: 540, height: 600), output: output, failures: &failures)
        // The render itself waits 0.8 s for the window to settle.
        print("KILL_PROCESS_RENDERING everything_ms=\(Int((Date().timeIntervalSince(started) - 0.8) * 1000))")
        defaults.set(KillProcessScope.background.rawValue, forKey: DefaultsKey.killProcessScopeSettings)
        SettingsRefactorProbe.render("settings-background", view: AnyView(KillProcessView(surface: .settings)),
            size: CGSize(width: 540, height: 600), output: output, failures: &failures)
        defaults.set(KillProcessScope.ports.rawValue, forKey: DefaultsKey.killProcessScopeHUD)
        let portRows = service.items.filter { !$0.ports.isEmpty }.prefix(1).map(\.pid)
        SettingsRefactorProbe.render("hud-ports", view: AnyView(
            KillProcessView(surface: .hud, expandedPIDs: [], expandedPortPIDs: Set(portRows)).padding(16)
                .background { HUDBackdrop(cornerRadius: 22, contrast: .standard) }),
            size: CGSize(width: 420, height: 520), output: output, failures: &failures)
        SettingsRefactorProbe.render("bluetooth-glyph", view: AnyView(
            HStack(spacing: 18) {
                ForEach([11.0, 13, 17, 24, 40], id: \.self) { size in
                    HStack(spacing: 4) {
                        LatticeSymbol(LatticeSymbol.bluetoothSymbol).font(.system(size: size, weight: .semibold))
                        Image(systemName: "wifi").font(.system(size: size, weight: .semibold))
                    }
                }
                LatticeSymbol(LatticeSymbol.bluetoothSymbol).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor).frame(width: 26, height: 26)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            }.padding(20)),
            size: CGSize(width: 520, height: 90), output: output, failures: &failures)
        SettingsRefactorProbe.render("refresh-glyph", view: AnyView(
            HStack(spacing: 18) {
                ForEach([11.0, 13, 17, 24, 40], id: \.self) { size in
                    HStack(spacing: 4) {
                        RefreshArrow(isSpinning: false).font(.system(size: size, weight: .medium))
                        Image(systemName: "arrow.clockwise").font(.system(size: size, weight: .medium))
                    }
                }
            }.padding(20)),
            size: CGSize(width: 520, height: 90), output: output, failures: &failures)
        SettingsRefactorProbe.setPreviewAvailability(.appUpdates, enabled: true)
        let updates = AppUpdatesService.shared
        updates.lastCheck = Date() // keeps the page from starting a real scan
        for checking in [false, true] {
            updates.isChecking = checking
            SettingsRefactorProbe.render("app-updates-" + (checking ? "checking" : "idle"),
                view: AnyView(AppUpdatesListView()), size: CGSize(width: 540, height: 200),
                output: output, failures: &failures)
        }
        updates.isChecking = false
        SettingsRefactorProbe.render("island", view: AnyView(
            KillProcessView(surface: .island).background(Color.black).environment(\.colorScheme, .dark)),
            size: CGSize(width: 388, height: 470), output: output, failures: &failures, colorScheme: .dark)
        defaults.removePersistentDomain(forName: identity)
        for failure in failures { print("KILL_PROCESS_RENDERING_FAILED \(failure)") }
        exit(failures.isEmpty ? 0 : 1)
    }
}
#endif
