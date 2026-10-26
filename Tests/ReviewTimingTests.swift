import SwiftUI

enum ReviewTimingTests {
    static func run(_ suite: TestSuite) {
        for (value, expected) in [(0, 200), (200, 200), (250, 250), (350, 350), (900, 900), (1500, 900)] {
            let dock = Dock(dockPreviewOpenDelay: value)
            suite.expect(dock.dockPreviewHoverDelayBinding.wrappedValue == expected,
                         "Dock Preview presents the effective delay for saved \(value) ms without mutating it")
        }
        suite.expect(QuitProtectionHoldPreset.allCases.map(\.rawValue).contains(2_000),
                     "the maximum supported two-second hold remains selectable after changing presets")
        suite.expect(QuitProtectionHoldPreset.default.rawValue == QuitProtectionSupport.defaultHoldDurationMilliseconds,
                     "the default hold preset uses the runtime default")
        suite.expect(QuitProtectionHoldPreset.short.title(.de) == "Kurz"
                     && QuitProtectionHoldPreset.default.title(.fr) == "Par défaut",
                     "hold preset labels follow the selected language")
        for language in AppLanguage.allCases {
            suite.expect(QuitProtectionHoldPreset.allCases.allSatisfy { !$0.title(language).isEmpty },
                         "all hold presets have localized titles for \(language)")
        }
    }
}
