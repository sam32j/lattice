import Foundation

enum RetiredSettingsFlowTests {
    static func run(_ suite: TestSuite) {
        let delegate = (try? String(contentsOfFile: "Sources/Vorssaint/App/AppDelegate.swift", encoding: .utf8)) ?? ""
        let hub = (try? String(contentsOfFile: "Sources/Vorssaint/UI/Settings/FeatureHubSettings.swift", encoding: .utf8)) ?? ""
        suite.expect(!delegate.isEmpty && !delegate.contains("showOnboarding")
                     && !delegate.contains("showUpdateHighlights") && !hub.contains("FeaturePreset"),
                     "startup and Settings have no retired onboarding, tour, or preset entry points")
        suite.expect(delegate.contains("func showUpdatePreview()")
                     && delegate.contains("UpdateService.shared.downloadAndInstall()"),
                     "removing introductions retains ordinary update review and installation")
        let cleaner = (try? String(contentsOfFile: "Sources/Vorssaint/UI/Cleaner/CleanerView.swift", encoding: .utf8)) ?? ""
        let runtime = (try? String(contentsOfFile: "Sources/Vorssaint/App/FeatureRuntime.swift", encoding: .utf8)) ?? ""
        suite.expect(!cleaner.isEmpty && !cleaner.contains("WhatsApp") && !cleaner.contains("whatsApp")
                     && !runtime.contains("WhatsApp"),
                     "Cleaner UI and runtime have no retired WhatsApp scheduler or organizer")
    }
}
