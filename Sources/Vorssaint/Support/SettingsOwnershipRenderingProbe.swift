#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Uses the existing test-only bundle identity and never enables live services.
enum SettingsOwnershipRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.vorssaint.tests.") == true else {
            failures.append("Settings ownership rendering requires an isolated test bundle.")
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.clipboardHistoryEnabled)
        defaults.set(true, forKey: DefaultsKey.shelfEnabled)
        defaults.set(true, forKey: AppFeature.scratchpad.availabilityKey)
        for target in [IslandDestination.clipboard, .files, .scratchpad] { target.setShown(true, in: defaults) }
        render("clipboard-island", AnyView(ClipboardSettings()), height: 1200, output: output, failures: &failures)
        render("file-cache-island", AnyView(ShelfSettings()), height: 1400, output: output, failures: &failures)
        render("scratchpad-island", AnyView(ScratchpadSettings()), height: 1200, output: output, failures: &failures)
        for (name, feature) in [("camera-preview", AppFeature.cameraPreview),
                                ("dmg-installer", .diskImageInstaller), ("launcher-grid", .quickLauncher)] {
            defaults.set(false, forKey: feature.availabilityKey)
            render(name, AnyView(DedicatedUtilitySettings(feature: feature)), height: 300,
                   output: output, failures: &failures)
        }
        defaults.set(false, forKey: DefaultsKey.notchHidesMenuBarIcon)
        AppMenuDestination.menuBar.save(in: defaults)
        render("general-app-menu", AnyView(GeneralSettings()), height: 700, output: output, failures: &failures)
        for target in [IslandDestination.clipboard, .files, .scratchpad] { target.setShown(false, in: defaults) }
        render("island-routing-off", AnyView(SettingsCard {
            IslandDestinationSettings(destination: .clipboard)
            IslandDestinationSettings(destination: .files)
            IslandDestinationSettings(destination: .scratchpad)
        }.padding(22)), height: 350, output: output, failures: &failures)
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchHidesMenuBarIcon)
        render("app-menu-no-target", AnyView(SettingsCard { AppMenuDestinationSettings() }.padding(22)),
               height: 220, output: output, failures: &failures)
        render("audio-pin-actions", AnyView(SettingsCard {
            ForEach([false, true], id: \.self) { pinned in
                HStack {
                    Text(pinned ? "Pinned app" : "App")
                    Spacer()
                    MixerPinButton(isPinned: pinned, pinTitle: "Pin to top", unpinTitle: "Unpin",
                                   appName: "App", action: {})
                }
            }
        }.padding(22)), height: 220, output: output, failures: &failures)
    }

    private static func render(_ name: String, _ view: AnyView, height: CGFloat,
                               output: URL, failures: inout [String]) {
        SettingsRefactorProbe.render(name, view: view, size: CGSize(width: 760, height: height),
                                    output: output, failures: &failures)
    }
}
#endif
