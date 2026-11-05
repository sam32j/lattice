// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Carbon.HIToolbox

/// The generated members are the real tile model, activation method and icon
/// methods. Only their environment is replaced: no windows, taps or capture.
enum LatticeHubContract {
    static var events: [String] = []
    static var cameraInNotch = false
    enum ReviewDefaults { static var current: UserDefaults! }
    enum LatticeHubService { static let columns = 3 }
    struct NSEvent {
        struct ModifierFlags: OptionSet {
            let rawValue: Int
            static let command = Self(rawValue: 1)
            static let control = Self(rawValue: 2)
            static let option = Self(rawValue: 4)
            static let shift = Self(rawValue: 8)
        }
        let keyCode: UInt16
        var modifierFlags: ModifierFlags = []
        var window: Window?
        var characters: String? = nil
    }
    final class Window { var firstResponder: AnyObject? }
    final class NSTextView {
        var composing = false
        func hasMarkedText() -> Bool { composing }
    }

    struct State {
        var isRecording = false
    }

    struct Deadline {
        let delay: Double
        static func now() -> Deadline { Deadline(delay: 0) }
        static func + (lhs: Deadline, rhs: Double) -> Deadline { Deadline(delay: lhs.delay + rhs) }
    }

    final class Queue {
        var jobs: [(Deadline, () -> Void)] = []
        func asyncAfter(deadline: Deadline, execute: @escaping () -> Void) {
            jobs.append((deadline, execute))
        }
        func drain() {
            let pending = jobs
            jobs.removeAll()
            pending.forEach { $0.1() }
        }
    }

    enum DispatchQueue { static let main = Queue() }
    struct Spy {
        let name: String
        func toggle() { events.append(name + ".toggle") }
        func capture() { events.append(name + ".capture") }
        func show() { events.append(name + ".show") }
        func showInNotchIfEnabled() -> Bool {
            guard name == "camera", cameraInNotch else { return false }
            events.append("camera.notch")
            return true
        }
        func showHistoryWindow() { events.append(name + ".showHistoryWindow") }
        func summon() { events.append(name + ".summon") }
        func activate() { events.append(name + ".activate") }
        func open(_ module: NotchModule) { events.append(name + ".open" + module.rawValue.capitalized) }
    }
    enum NotchModule: String { case agents, watch, system }
    enum NotchService { static let shared = Spy(name: "notch") }
    enum KeepAwakeManager { static let shared = Spy(name: "keepAwake") }
    enum MicMuteService { static let shared = Spy(name: "micMute") }
    enum ScreenshotService { static let shared = Spy(name: "screenshot") }
    enum ScreenRecorderService { static let shared = Spy(name: "recorder") }
    enum CameraPreviewService { static let shared = Spy(name: "camera") }
    enum ScratchpadService { static let shared = Spy(name: "scratchpad") }
    enum ClipboardHistoryService { static let shared = Spy(name: "clipboard") }
    enum ShelfService { static let shared = Spy(name: "shelf") }
    enum SnippetLibraryService { static let shared = Spy(name: "snippets") }
    enum CleaningModeManager { static let shared = Spy(name: "cleaning") }

    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.quick-launcher-presentation"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        ReviewDefaults.current = defaults
        defer {
            ReviewDefaults.current = nil
            defaults.removePersistentDomain(forName: domain)
        }
        for feature in AppFeature.allCases { defaults.set(true, forKey: feature.availabilityKey) }
        for key in [DefaultsKey.shelfEnabled, DefaultsKey.clipboardHistoryEnabled, DefaultsKey.urlCleanerEnabled, DefaultsKey.textSnippetsEnabled, DefaultsKey.videoDownloaderEnabled] { defaults.set(true, forKey: key) }
        defaults.set(true, forKey: DefaultsKey.microphoneLevelControlEnabled)
        defaults.set(false, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        cameraInNotch = false
        let cases: [(LatticeHubItem, AppFeature, String?, Double?)] = [
            (.screenshot, .screenshot, "screenshot.capture", 0.15),
            (.screenRecorder, .screenRecorder, "recorder.toggle", 0.15),
            (.scratchpad, .scratchpad, "scratchpad.show", 0.15),
            (.clipboard, .clipboardHistory, "clipboard.showHistoryWindow", 0.1),
            (.windowLayout, .windowLayout, nil, nil),
            (.homebrew, .homebrew, nil, nil),
            (.media, .mediaTools, nil, nil),
            (.urlCleaner, .urlCleaner, nil, nil),
            (.uninstaller, .uninstaller, nil, nil),
            (.cleaner, .cleaner, nil, nil),
            (.appUpdates, .appUpdates, nil, nil),
            (.portManager, .portManager, nil, nil),
            (.shelf, .shelf, "shelf.summon", 0.15),
            (.textSnippets, .textSnippets, "snippets.show", 0.15),
            (.killProcess, .killProcess, nil, nil),
            (.wallpaper, .wallpaper, nil, nil),
            (.videoDownloader, .videoDownloader, nil, nil),
            (.recentCaptures, .screenshot, nil, nil),
            (.deviceControls, .mixer, nil, nil),
            (.aiUsage, .notchAgents, "notch.openAgents", 0.1),
            (.watch, .notchWatch, "notch.openWatch", 0.1),
            (.system, .monitorCPU, "notch.openSystem", 0.1),
        ]
        suite.expect(Set(cases.map { $0.0 }) == Set(LatticeHubItem.allCases),
                     "every launcher tile has an activation contract")
        for (item, feature, action, delay) in cases {
            events.removeAll()
            DispatchQueue.main.jobs.removeAll()
            let launcher = Launcher()
            launcher.run(item)
            suite.expect(item.feature == feature, "\(item) follows its own feature switch")
            if let delay, let action {
                suite.expect(events == ["hide"] && launcher.activeUtility == nil,
                             "\(item) dismisses the launcher before any external action")
                suite.expect(DispatchQueue.main.jobs.count == 1
                             && DispatchQueue.main.jobs.first?.0.delay == delay,
                             "\(item) schedules exactly one action after dismissal")
                DispatchQueue.main.drain()
                suite.expect(events == ["hide", action], "\(item) executes the intended action exactly once")
            } else if let action {
                suite.expect(events == [action] && DispatchQueue.main.jobs.isEmpty
                             && launcher.activeUtility == nil,
                             "\(item) toggles immediately without dismissing or opening a utility")
            } else {
                suite.expect(events.isEmpty && DispatchQueue.main.jobs.isEmpty
                             && launcher.activeUtility == item,
                             "\(item) opens its utility inside the launcher")
            }
            events.removeAll()
            launcher.isEditing = true
            launcher.activeUtility = nil
            launcher.run(item)
            DispatchQueue.main.drain()
            suite.expect(events.isEmpty && launcher.activeUtility == nil,
                         "editing \(item) never activates it")
        }
        events.removeAll()
        DispatchQueue.main.jobs.removeAll()
        suite.expect(!LatticeHubItem.allCases.contains { $0.rawValue == "cameraPreview" },
                     "Camera Preview belongs to quick controls rather than workflow tiles")
        var tile = Tile()
        suite.expect(tile.icon(for: .screenRecorder) == "record.circle",
                     "an idle recording tile offers recording")
        tile.recorder.isRecording = true
        suite.expect(tile.icon(for: .screenRecorder) == "stop.circle",
                     "an active recording tile offers stopping")
        suite.expect(LatticeHubItem.allCases.allSatisfy { !tile.icon(for: $0).isEmpty },
                     "every tile has an icon")
        presentationContracts(suite)
        compositionContracts(suite)
        railContracts(suite)
    }

    private static func presentationContracts(_ suite: TestSuite) {
        let launcher = Launcher()
        let oldPresentation = launcher.presentationID
        launcher.isEditing = true
        launcher.editingOptionsItem = .clipboard
        launcher.prepareForPresentation()
        suite.expect(launcher.presentationID != oldPresentation && !launcher.isEditing
                     && launcher.editingOptionsItem == nil && launcher.selectedIndex == nil,
                     "a new presentation resets edit controls and clears initial tile selection")
        events.removeAll()
        let enter = NSEvent(keyCode: UInt16(kVK_Return))
        suite.expect(launcher.handlePanelKey(enter) == nil && events.isEmpty,
                     "Return does not activate anything when no tile is selected")
        let down = NSEvent(keyCode: UInt16(kVK_DownArrow))
        suite.expect(launcher.handlePanelKey(down) == nil && launcher.selectedIndex == 0,
                     "navigating with arrow keys selects the first tile")
        suite.expect(launcher.handlePanelKey(enter) == nil && events == ["hide"],
                     "Return activates the selected item")
        DispatchQueue.main.drain()
        suite.expect(events == ["hide", "screenshot.capture"], "the first item executes its action")
        events.removeAll()
        DispatchQueue.main.jobs.removeAll()
        launcher.prepareForPresentation()
        let tab = NSEvent(keyCode: UInt16(kVK_Tab))
        suite.expect(launcher.handlePanelKey(tab) == nil && launcher.selectedIndex == 0,
                     "Tab selects the first item when unselected")
        suite.expect(launcher.handlePanelKey(tab) == nil && launcher.selectedIndex == 1,
                     "Tab advances to the second item")
        let space = NSEvent(keyCode: UInt16(kVK_Space))
        suite.expect(launcher.handlePanelKey(space) == nil && events == ["hide"],
                     "Space activates the selected item")
        DispatchQueue.main.drain()
        events.removeAll()
        DispatchQueue.main.jobs.removeAll()
        suite.expect(launcher.handlePanelKey(NSEvent(keyCode: UInt16(kVK_ANSI_Keypad1))) != nil
                     && events.isEmpty,
                     "numeric keys no longer activate items directly")
        for item in [LatticeHubItem.urlCleaner, .homebrew, .uninstaller, .media] {
            launcher.activeUtility = item
            launcher.prepareForPresentation()
            suite.expect(launcher.activeUtility == item,
                         "reopening preserves the working utility while its feature remains installed")
            let key = item == .urlCleaner ? DefaultsKey.urlCleanerEnabled : item.feature.availabilityKey
            ReviewDefaults.current.set(false, forKey: key)
            launcher.editingOptionsItem = item
            launcher.refreshAvailability()
            suite.expect(launcher.activeUtility == nil && launcher.editingOptionsItem == nil,
                         "removing a feature clears both its hosted utility and its edit options")
            launcher.activeUtility = item
            launcher.prepareForPresentation()
            suite.expect(launcher.activeUtility == nil,
                         "a utility removed while the island was closed cannot return on reopening")
            events.removeAll()
            launcher.run(item)
            suite.expect(launcher.activeUtility == nil && events.isEmpty,
                         "a stale tile action cannot activate a removed feature")
            ReviewDefaults.current.set(true, forKey: key)
        }
        launcher.candidates = []
        launcher.prepareForPresentation()
        events.removeAll()
        suite.expect(launcher.selectedIndex == nil && launcher.handlePanelKey(enter) == nil && events.isEmpty,
                     "an empty launcher has no imaginary initial action")
    }

    /// Each Esc step, reached while a utility's field holds an input method
    /// that is still composing: none may take the key from it.
    private static func compositionContracts(_ suite: TestSuite) {
        let field = NSTextView()
        let window = Window()
        window.firstResponder = field
        let escape = NSEvent(keyCode: UInt16(kVK_Escape), window: window)
        let steps: [(name: String, open: (Launcher) -> Void, closed: (Launcher) -> Bool)] = [
            ("the hosted utility", { $0.activeUtility = .homebrew }, { $0.activeUtility == nil }),
            ("the options card", { $0.isEditing = true; $0.editingOptionsItem = .clipboard },
             { $0.editingOptionsItem == nil && $0.isEditing }),
            ("edit mode", { $0.isEditing = true }, { !$0.isEditing }),
            ("the launcher", { _ in }, { _ in events == ["hide"] }),
        ]
        for step in steps {
            let launcher = Launcher()
            step.open(launcher)
            events.removeAll()
            field.composing = true
            suite.expect(launcher.handlePanelKey(escape) != nil && !step.closed(launcher) && events.isEmpty,
                         "a composing input method keeps Esc from closing \(step.name)")
            field.composing = false
            suite.expect(launcher.handlePanelKey(escape) == nil && step.closed(launcher),
                         "Esc closes \(step.name) once composition ends")
        }
    }

    /// Hover and the arrows both select, but only the arrows move the
    /// island's rail: scrolling to a hovered tile slid the next one under the
    /// pointer, and the rail kept going.
    private static func railContracts(_ suite: TestSuite) {
        let launcher = Launcher()
        launcher.prepareForPresentation()
        suite.expect(launcher.keyboardIndex == nil, "a new presentation starts with no initial rail highlight until navigated")
        launcher.select(launcher.visibleItems[3])
        suite.expect(launcher.selectedIndex == 3 && launcher.keyboardIndex == nil,
                     "hovering a tile selects it without scrolling the rail")
        let right = NSEvent(keyCode: UInt16(kVK_RightArrow))
        suite.expect(launcher.handlePanelKey(right, flow: .columns(rows: 2)) == nil
                     && launcher.selectedIndex == 5 && launcher.keyboardIndex == 5,
                     "an arrow moves on from the hovered tile and scrolls the rail to the new one")
    }
}
