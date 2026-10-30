import Foundation
import SwiftUI

/// Exercise production input handlers without opening panels or changing preferences.
enum NotchReviewInteractionContract {
    struct PowerReading { var chargePercent: Int?; var isCharging = false; var externalConnected = false }
    final class Window {}
    struct NSEvent { let keyCode: UInt16; var window: Window? }
    class EditorState {
        var panel: Window? = Window()
        var pickerPresented = false
        var dismissals = 0
        func dismiss() { dismissals += 1 }
    }
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
    class RoutingState {
        let defaults: UserDefaults
        var reduceMotion = true
        var launcherIslandRoute: Bool { defaults.object(forKey: DefaultsKey.notchQuickPanel) as? Bool ?? true }
        var launcherShortcutTarget: String {
            get { defaults.string(forKey: DefaultsKey.launcherShortcutTarget) ?? "automatic" }
            set { defaults.set(newValue, forKey: DefaultsKey.launcherShortcutTarget) }
        }
        init(_ defaults: UserDefaults) { self.defaults = defaults }
    }
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
        let domain = "io.github.sam32j.lattice.tests.pr26-routing.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: DefaultsKey.notchQuickPanel)
        defaults.set("tools,hub,clipboard", forKey: DefaultsKey.notchHiddenModules)
        let routing = C.LauncherSettings(defaults)
        suite.expect(!routing.launcherIslandShown.wrappedValue,
                     "a hidden Hub route cannot look enabled just because shortcut routing is automatic")
        routing.launcherIslandShown.wrappedValue = true
        suite.expect(IslandDestination.launcherGrid.isShown(in: defaults)
            && defaults.string(forKey: DefaultsKey.notchHiddenModules) == "clipboard"
            && LauncherShortcutTarget.selected(in: defaults) == .automatic,
            "enabling the island destination restores its route and both canonical/legacy hidden keys")
        routing.launcherIslandShown.wrappedValue = false
        suite.expect(!IslandDestination.launcherGrid.isShown(in: defaults)
            && LauncherShortcutTarget.selected(in: defaults) == .floatingWindow,
            "disabling the island destination consistently uses the floating route")
        let editor = C.Editor()
        suite.expect(editor.handleKey(C.NSEvent(keyCode: 53, window: C.Window())) != nil && editor.dismissals == 0,
                     "Escape in another window leaves the quick-action editor open")
        editor.pickerPresented = true
        suite.expect(editor.handleKey(C.NSEvent(keyCode: 53, window: editor.panel)) != nil && editor.dismissals == 0,
                     "Escape dismisses a picker before the quick-action editor")
        editor.pickerPresented = false
        suite.expect(editor.handleKey(C.NSEvent(keyCode: 53, window: editor.panel)) == nil && editor.dismissals == 1,
                     "Escape in the editor dismisses it when no picker is open")
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
