#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

enum RefactorUtilityRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Utility rendering requires an isolated test bundle."); return
        }
        let defaults = UserDefaults.standard
        DockClickSettingsProbe.run(output: output, failures: &failures)
        for island in [true, false] {
            defaults.set(island, forKey: DefaultsKey.notchEnabled)
            for enabled in [true, false] {
                for feature in [AppFeature.clipboardHistory, .scratchpad, .shelf, .cameraPreview, .quickLauncher] {
                    SettingsRefactorProbe.setPreviewAvailability(feature, enabled: enabled)
                }
                defaults.set(enabled, forKey: DefaultsKey.clipboardHistoryEnabled)
                defaults.set(enabled, forKey: DefaultsKey.shelfEnabled)
                for destination in [IslandDestination.clipboard, .files, .scratchpad, .cameraPreview, .launcherGrid] {
                    destination.setShown(true, in: defaults)
                }
                let pages: [(String, AnyView)] = [
                    ("clipboard", AnyView(ClipboardSettings())), ("scratchpad", AnyView(ScratchpadSettings())),
                    ("file-cache", AnyView(ShelfSettings())),
                    ("camera", AnyView(DedicatedUtilitySettings(feature: .cameraPreview))),
                    ("launcher", AnyView(DedicatedUtilitySettings(feature: .quickLauncher))) ]
                for (name, view) in pages {
                    verifyChildren(name: name, view: view, enabled: enabled, island: island,
                                   failures: &failures)
                    SettingsRefactorProbe.render("\(name)-\(enabled ? "on" : "off")-island-\(island ? "on" : "off")",
                        view: view, size: CGSize(width: 760, height: name == "camera" || name == "launcher" ? 350 : 1500),
                        output: output, failures: &failures)
                }
            }
        }
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        SettingsRefactorProbe.setPreviewAvailability(.cameraPreview, enabled: true)
        verifyChildren(name: "camera", view: AnyView(DedicatedUtilitySettings(feature: .cameraPreview)),
                       enabled: false, island: true, cameraGranted: false, failures: &failures)
        SettingsRefactorProbe.render("shortcut-row-alignment", view: AnyView(SettingsCard {
            ShortcutPreferenceRow(role: .clipboard, label: "Open Clipboard History") {}
            ShortcutPreferenceRow(role: .snippetLibrary, label: "Search snippets", symbolName: "text.bubble",
                statusText: "Inactive", statusIsActive: false) {}
        }.padding(22)), size: CGSize(width: 760, height: 220), output: output, failures: &failures)
        for phase in [PermissionResetState.Phase.ready, .restartRequired, .failed] {
            SettingsRefactorProbe.render("permission-reset-\(phase)",
                view: AnyView(SettingsCard {
                    PermissionResetSettingsRow(state: PermissionResetState(phase: phase), reset: { _ in }, restart: {})
                }.padding(22)), size: CGSize(width: 760, height: 240), output: output, failures: &failures)
        }
        for overlaps in [false, true] {
            for dragging in [false, true] {
                let model = CaptureGuideViewModel()
                model.overlapsSelection = overlaps
                model.isAreaDragging = dragging
                let options = ScreenCaptureSelectionOptions(availableTools: [.screenshot, .recording],
                    selectedTool: .screenshot, showsCaptureMenu: true)
                let view = CaptureGuideView(strings: FeatureStrings.screenshot(.enUS), purpose: nil, model: model,
                    screenCaptureOptions: options, onFullScreen: {}, onToggleScrolling: {}, onToggleLoupe: {},
                    onRepeatLastRegion: {}, onToggleMode: {}, onCancel: {})
                SettingsRefactorProbe.render("actual-toolbar-overlap-\(overlaps)-dragging-\(dragging)",
                    view: AnyView(ZStack {
                        LinearGradient(colors: [.blue, .yellow, .red], startPoint: .leading, endPoint: .trailing)
                        view.frame(width: 620)
                    }), size: CGSize(width: 760, height: 180), output: output, failures: &failures)
            }
        }
    }

    /// Native visibility/order checks use isolated preferences and an injected
    /// permission verifier. No grant, camera session or enable action is invoked.
    private static func verifyChildren(name: String, view: AnyView, enabled: Bool, island: Bool,
                                       cameraGranted: Bool = true, failures: inout [String]) {
        let titles = ["clipboard": "Clipboard History", "scratchpad": "Scratchpad",
                      "file-cache": "File Cache", "camera": "Camera Preview", "launcher": "Launcher Grid"]
        let open = "Open \(titles[name]!)"
        var requests = 0
        let access = SettingsPermissionAccessors(verify: { $0 != .camera || cameraGranted },
            request: { _, reply in requests += 1; reply(.denied) })
        let host = NSHostingView(rootView: view.environment(\.settingsPermissionAccess, access))
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 760, height: 1500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        let getter = NSSelectorFromString("accessibilityAttributeValue:")
        let setter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let previous = NSApp.perform(getter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
        NSApp.perform(setter, with: true, with: "AXEnhancedUserInterface")
        defer {
            NSApp.perform(setter, with: previous, with: "AXEnhancedUserInterface")
            window.orderOut(nil); window.contentView = nil; window.close()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        let labels = staticLabels(in: host)
        if requests != 0 { failures.append("Rendering must never request permission.") }
        let shortcutIndex = labels.firstIndex(of: open)
        let islandIndex = labels.firstIndex(of: "Show on Dynamic Island")
        if (shortcutIndex != nil) != enabled || (islandIndex != nil) != (enabled && island) {
            failures.append("\(name) child visibility disagrees with effective enablement (enabled=\(enabled), camera=\(cameraGranted)): \(labels)")
        }
        if name == "launcher" {
            if let shortcutIndex, let islandIndex, islandIndex >= shortcutIndex {
                failures.append("\(name) Show on Dynamic Island must appear before Open shortcut.")
            }
        } else {
            if let shortcutIndex, let islandIndex, shortcutIndex >= islandIndex {
                failures.append("\(name) Open shortcut must appear before Show on Dynamic Island.")
            }
        }
    }

    private static func staticLabels(in element: AnyObject) -> [String] {
        var result: [String] = []
        if element.accessibilityRole?() == .staticText {
            if let label = element.accessibilityLabel?(), !label.isEmpty { result.append(label) }
            if let value = (element as? NSObject)?.perform(NSSelectorFromString("accessibilityValue"))?.takeUnretainedValue() as? String,
               !value.isEmpty, !result.contains(value) { result.append(value) }
        }
        for child in element.accessibilityChildren?() ?? [] { result += staticLabels(in: child as AnyObject) }
        return result
    }
}
#endif
