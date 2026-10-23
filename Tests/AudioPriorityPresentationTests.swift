import Foundation

enum AudioPriorityPresentationTests {
    static func run(_ suite: TestSuite) {
        let uuid = "9a90d39d-1ff6-4b11-bb25-495e202f8f2c-128331854022041-Audio"
        let mac = "76:A5:07:F9:37:25-118951891364875-screen"
        let saved = [uuid, mac, "airpods", "speakers", "nameless"]
        let names = [uuid: uuid, mac: mac, "airpods": "AirPods Pro", "speakers": "MacBook Air Speakers"]
        let visible = AudioPriorityPresentation.visibleUIDs(saved, isAvailable: { $0 == "speakers" },
                                                           displayName: { names[$0] })
        suite.expect(visible == ["airpods", "speakers"],
                     "priority list keeps named disconnected devices but hides stale technical identifiers")
        suite.expect(AudioPriorityPresentation.visibleUIDs([uuid, "nameless"], isAvailable: { _ in true },
                     displayName: { names[$0] }) == [uuid, "nameless"],
                     "every connected device remains configurable even without a friendly name")
        suite.expect(AudioPriorityPresentation.mergingVisibleOrder(["speakers", "airpods"], into: saved)
                     == [uuid, mac, "speakers", "airpods", "nameless"],
                     "visible reordering preserves hidden entries and their priority slots")
        suite.expect(AudioPriorityPresentation.mergingVisibleOrder([], into: saved) == saved,
                     "an empty visible list never clears saved device preferences")
        let interleaved = ["hidden-a", "airpods", "hidden-b", "speakers", "hidden-c"]
        let reversed = AudioPriorityPresentation.mergingVisibleOrder(["speakers", "airpods"], into: interleaved)
        suite.expect(reversed == ["hidden-a", "speakers", "hidden-b", "airpods", "hidden-c"]
                     && AudioPriorityPresentation.mergingVisibleOrder(["airpods", "speakers"], into: reversed) == interleaved,
                     "reordering in both directions retains interleaved hidden device slots")
        for language in AppLanguage.allCases {
            for shortcut in ["⌘Q", "⌘W"] {
                let allow = QuitProtectionAppListStrings.text(enabledOnly: true, shortcut: shortcut, language: language)
                let deny = QuitProtectionAppListStrings.text(enabledOnly: false, shortcut: shortcut, language: language)
                suite.expect(!allow.title.isEmpty && allow.title != deny.title
                             && allow.caption.contains(shortcut) && deny.caption.contains(shortcut)
                             && allow.caption != deny.caption,
                             "quit/close ALS titles and descriptions distinguish inclusion from exclusion in \(language)")
            }
        }
    }
}
