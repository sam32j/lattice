#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Runs before normal startup with a separate application preferences domain.
enum FeaturePageMigrationPreview {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier,
              identity.hasPrefix("io.github.sam32j.lattice.tests."),
              let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        catch { fputs("Cannot create preview output: \(error)\n", stderr); exit(2) }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        defaults.register(defaults: Defaults.registeredDefaults)
        defaults.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        for feature in AppFeature.allCases {
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: false)
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        var failures: [String] = []
        if CommandLine.arguments.contains("--feature-disablement-only") {
            FeatureDisablementProbe.run(output: output, failures: &failures)
        } else {
            FeaturePageMigrationRenderingProbe.run(output: output, failures: &failures)
            WorkspaceEmptyStateProbe.run(output: output, failures: &failures)
        }
        defaults.removePersistentDomain(forName: identity)
        for failure in failures { print("FEATURE_MIGRATION_PREVIEW_FAILED \(failure)") }
        if failures.isEmpty { print("FEATURE_MIGRATION_PREVIEW_OK output=\(output.path)") }
        exit(failures.isEmpty ? 0 : 1)
    }
}
#endif
