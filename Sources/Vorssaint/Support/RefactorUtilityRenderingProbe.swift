#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

enum RefactorUtilityRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.vorssaint.tests.") == true else {
            failures.append("Utility rendering requires an isolated test bundle."); return
        }
        let defaults = UserDefaults.standard
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
                    SettingsRefactorProbe.render("\(name)-\(enabled ? "on" : "off")-island-\(island ? "on" : "off")",
                        view: view, size: CGSize(width: 760, height: name == "camera" || name == "launcher" ? 350 : 1500),
                        output: output, failures: &failures)
                }
            }
        }
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
}
#endif
