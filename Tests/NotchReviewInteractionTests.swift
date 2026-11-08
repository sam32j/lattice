import Foundation
import SwiftUI

/// Exercise production input handlers without opening panels or changing preferences.
enum NotchReviewInteractionContract {
    struct PowerReading { var chargePercent: Int?; var isCharging = false; var externalConnected = false }
    final class Window {}
    struct NSEvent { let keyCode: UInt16; var window: Window? }
    struct Entry { let id = UUID() }
    final class Library {
        var query = "foo"
        var entries = [Entry()]
        var rows: [Entry] { query.isEmpty ? entries : [] }
        func reloadSnippets() {}
    }
    class SnippetState {
        var preview = false
        let library = Library()
        var searchOpen = false
        var highlightedID: UUID?
        var searching = false
    }
    enum AppFeature { enum textSnippets { static let isAvailable = true } }
    struct TextSnippet {}
    enum NotchService {
        static let shared = Island()
        final class Island {
            var expanded = false
            var collapses = 0
            func collapse() { collapses += 1 }
            func syncWithPreferences() {}
        }
    }
    class InsertionState { func hide() {} }
    enum Command { case next }
    enum Module { case music }
    final class Music {
        var commandFailed = true
        var sends = 0
        @discardableResult func send(_ command: Command) -> Bool { sends += 1; return true }
    }
    final class MusicService {
        var activations = 0, opens = 0
        func activateMusicStrip() { activations += 1 }
        func openActivity(_ module: Module) { opens += 1 }
    }
    class MusicState { let music = Music(); let service = MusicService(); var live = true }
    enum LatticeHubService { static let shared = Hub() }
    final class Hub { func syncWithPreferences() {} }
}

enum NotchReviewInteractionTests {
    static func run(_ suite: TestSuite) {
        suite.expect(NotchLayout.toolRailRows(count: 15, width: 400, height: 240) == 2,
                     "large preset Hub catalogs preserve the intentional two-row rail")
        typealias C = NotchReviewInteractionContract
        suite.expect(C.NotchRestingBattery.tint(for: C.PowerReading(chargePercent: 10)) == Color.red
            && C.NotchRestingBattery.tint(for: C.PowerReading(chargePercent: 20)) == Color.orange,
            "the island retains the accepted fixed-on red and amber battery policy")
        // Editing Quick Access now uses the live Island, not the retired
        // separate panel and its Escape-to-dismiss monitor.
        let editorSource = (try? String(contentsOfFile:
            "Sources/Lattice/UI/Notch/NotchLiveQuickActionsEditorController.swift",
            encoding: .utf8)) ?? ""
        suite.expect(editorSource.contains("NotchService.shared.open(.hub")
                   && editorSource.contains("LatticeHubService.shared.isEditing = true")
                   && !editorSource.contains("NotchLiveQuickActionsEditorView("),
                     "Quick Access editing uses the real island and Hub edit state")
        let accessSource = (try? String(contentsOfFile:
            "Sources/Lattice/UI/Notch/NotchQuickAccessView.swift",
            encoding: .utf8)) ?? ""
        suite.expect(accessSource.contains("editingBubble(placement)")
                   && accessSource.contains("NotchQuickActionPicker(")
                   && accessSource.contains("saveEditingConfiguration(configuration)"),
                     "live quick-access gutters support selecting, adding, and removing actions")
        let snippets = C.SnippetPage()
        snippets.appeared()
        suite.expect(snippets.library.query.isEmpty && !snippets.searchOpen
            && snippets.highlightedID == snippets.library.entries.first?.id,
            "opening Snippets clears a hidden stale filter and selects the first visible item")
        let preview = C.SnippetPage(); preview.preview = true; preview.appeared()
        suite.expect(preview.library.query == "foo", "settings preview leaves live snippet state alone")
        let insertion = C.Insertion()
        C.NotchService.shared.expanded = false; C.NotchService.shared.collapses = 0
        insertion.insert(C.TextSnippet())
        suite.expect(C.NotchService.shared.collapses == 0, "floating insertion preserves an unrelated compact capture")
        C.NotchService.shared.expanded = true
        insertion.insert(C.TextSnippet())
        suite.expect(C.NotchService.shared.collapses == 1, "insertion closes the expanded island")
        let strip = C.MusicStrip()
        strip.activateStrip()
        suite.expect(strip.service.activations == 1 && strip.music.sends == 0,
                     "failed playback commands cannot replace the live strip click with a track skip")
        strip.live = false; strip.activateStrip()
        suite.expect(strip.service.opens == 1 && strip.music.sends == 0,
                     "a departing strip still navigates to Music after command failure")
    }
}
