#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Isolated preferences and in-process executors only. No utility operation,
/// permission request, process launch or system change is performed.
enum FeatureDisablementProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Disablement verification requires an isolated identity.")
            return
        }
        for feature in AppFeature.migratedPageFeatures where FeatureRuntime.bindings[feature] == nil {
            failures.append("Missing runtime activation binding: \(feature.rawValue)")
        }
        backendOwnership(failures: &failures)
        processMutation(failures: &failures)
        hubAvailability(failures: &failures)
    }

    private static func backendOwnership(failures: inout [String]) {
        for feature in [AppFeature.homebrew, .uninstaller, .appUpdates] {
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: true)
        }
        let brew = HomebrewManager.shared
        let browser = brew.readWork.begin(owner: .homebrew, isAvailable: { $0.isAvailable })!
        let remover = brew.readWork.begin(owner: .uninstaller, isAvailable: { $0.isAvailable })!
        let updater = brew.readWork.begin(owner: .appUpdates, isAvailable: { $0.isAvailable })!
        var executions = 0
        let executor: FeatureReadProcess.Executor = { _, _ in
            executions += 1
            return .init(status: 0, output: Data("completed".utf8), timedOut: false)
        }
        FeatureRuntime.shared.setPageEnabled(.homebrew, false)
        let stopped = FeatureReadProcess.run("fixture", [], cancellation: browser, executor: executor)
        let kept = FeatureReadProcess.run("fixture", [], cancellation: remover, executor: executor)
        if !browser.isCancelled || stopped.status == 0 || remover.isCancelled || updater.isCancelled
            || kept.status != 0 || executions != 1 {
            failures.append("Homebrew disable did not cancel only its owned read scope.")
        }
        FeatureRuntime.shared.setPageEnabled(.appUpdates, false)
        if !updater.isCancelled || remover.isCancelled {
            failures.append("App Updates disable disturbed the Uninstaller's backend scope.")
        }
        FeatureRuntime.shared.setPageEnabled(.uninstaller, false)
        if !remover.isCancelled { failures.append("Uninstaller scope survived disable.") }
        print("FEATURE_DISABLEMENT_BACKEND stopped=\(stopped.status) kept=\(kept.status) executions=\(executions)")
    }

    private static func processMutation(failures: inout [String]) {
        let runtime = FeatureRuntime.shared
        runtime.setPageEnabled(.killProcess, true)
        runtime.setPageEnabled(.portManager, true)
        let processes = KillProcessService.shared
        processes.beginProtectedAction(.portManager) // State only; no process action.
        runtime.setPageEnabled(.killProcess, false)
        runtime.setPageEnabled(.portManager, false)
        if !AppFeature.killProcess.isAvailable || !AppFeature.portManager.isAvailable {
            failures.append("Disable interrupted a protected process action or its owner.")
        }
        processes.endProtectedAction(.portManager)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        runtime.setPageEnabled(.portManager, false)
        runtime.setPageEnabled(.killProcess, false)
        if AppFeature.killProcess.isAvailable || AppFeature.portManager.isAvailable {
            failures.append("Process owners could not disable after the protected action finished.")
        }
    }

    private static func hubAvailability(failures: inout [String]) {
        let feature = AppFeature.homebrew
        SettingsRefactorProbe.setPreviewAvailability(feature, enabled: true)
        let hub = LatticeHubService.shared
        hub.activeUtility = .homebrew
        FeatureRuntime.shared.setPageEnabled(feature, false)
        if hub.activeUtility != nil { failures.append("Disabling did not close the current Hub utility.") }
        FeatureRuntime.shared.setPageEnabled(feature, true)
        if hub.activeUtility != nil { failures.append("Re-enabling reopened a dismissed Hub utility.") }
        FeatureRuntime.shared.setPageEnabled(feature, false)
    }
}
#endif
