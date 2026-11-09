// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// The central controller for Lattice Hub: presents either a floating HUD
/// (summoned via ⌃⌘V or anchored below the menu bar) or coordinates with the
/// Dynamic Island.
final class LatticeHubService: ObservableObject {
    static let shared = LatticeHubService()
    static let columns = 3

    @Published private(set) var shortcutRegistrationFailed = false
    @Published var stayAwakeOptionsPresented = false
    let editingPresentation = HubEditingPresentation()
    var editingChangedAt: TimeInterval = -.infinity
    @Published var isEditing = false {
        didSet {
            guard isEditing != oldValue else { return }
            editingChangedAt = ProcessInfo.processInfo.systemUptime
            if isEditing, NotchSupport.usesHapticFeedback() {
                TrackpadActuator.shared.actuate(waveform: 3) {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            editingPresentation.setEditing(isEditing, options: editingOptionsItem)
            if !isEditing { editingOptionsItem = nil }
        }
    }
    @Published var editingOptionsItem: LatticeHubItem?
    @Published var activeUtility: LatticeHubItem? {
        didSet {
            if let activeUtility {
                UserDefaults.standard.set(activeUtility.rawValue, forKey: DefaultsKey.recentHubUtility)
            }
        }
    }
    // One stable layout budget for the floating panel, established when it is
    // positioned. SwiftUI must never derive its content height from the
    // *animating* window frame, or the two systems feed back into each other.
    @Published private(set) var floatingPanelHeightBudget: CGFloat = .greatestFiniteMagnitude
    let panelResizer = HubPanelResizer()

    func setFloatingPanelHeightBudget(_ height: CGFloat) {
        guard height.isFinite, height >= 100,
              abs(floatingPanelHeightBudget - height) > 0.5 else { return }
        floatingPanelHeightBudget = height
    }
    var recentUtility: LatticeHubItem? {
        guard let raw = UserDefaults.standard.string(forKey: DefaultsKey.recentHubUtility),
              let item = LatticeHubItem(rawValue: raw),
              item.isAvailable() else {
            return nil
        }
        return item
    }
    @Published var isPinned: Bool = false
    @Published var selectedIndex: Int?
    @Published var keyboardIndex: Int?
    @Published var navigationToken = UUID()
    @Published var hubIslandPage: Int = 0
    var lastDismissedTime: TimeInterval = 0
    var lastKeyboardActionTimestamp: TimeInterval = 0
    @Published var presentationID = UUID() {
        didSet { editingPresentation.reset() }
    }
    @Published var hiddenItemsRaw: String = UserDefaults.standard.string(
        forKey: DefaultsKey.quickLauncherHiddenItems) ?? ""

    private let hotkey = QuickToolHotkey(id: 14)
    var panel: NSPanel?
    var previousApp: NSRunningApplication?
    var keyMonitor: Any?
    var localClickMonitor: Any?
    var outsideClickMonitor: Any?
    var globalKeyMonitor: Any?
    var activationObserver: NSObjectProtocol?
    var resignActiveObserver: NSObjectProtocol?
    var resignKeyObserver: NSObjectProtocol?
    var otherKeyObserver: NSObjectProtocol?
    var spaceChangeObserver: NSObjectProtocol?
    var screenChangeObserver: NSObjectProtocol?
    var missionControlTimer: Timer?

    private var notchSubscription: AnyCancellable?

    private init() {
        hotkey.onPress = { [weak self] in self?.toggle() }
        notchSubscription = NotchService.shared.$expanded
            .dropFirst()
            .sink { [weak self] expanded in
                guard let self, !expanded, NotchService.shared.selected == .hub else { return }
                if UserDefaults.standard.bool(forKey: DefaultsKey.notchReturnHome) {
                    self.activeUtility = nil
                }
                self.isEditing = false
                self.isPinned = false
            }
    }

    func syncWithPreferences() {
        guard AppFeature.quickLauncher.isAvailable else {
            suspend()
            return
        }
        let enabled = AppFeature.quickLauncher.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.quickLauncherShortcutEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.quickLauncherShortcut,
                                            fallback: .quickLauncherDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.quickLauncherShortcut)
    }

    func suspend() {
        hotkey.unregister()
        hide()
    }

    func openSettings() {
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    // MARK: - Items

    var visibleItems: [LatticeHubItem] {
        let hidden = QuickToolsSupport.hiddenIDs(from: hiddenItemsRaw)
        return orderedItems.filter { !hidden.contains($0.rawValue) }
    }

    var hiddenItems: [LatticeHubItem] {
        let hidden = QuickToolsSupport.hiddenIDs(from: hiddenItemsRaw)
        return orderedItems.filter { hidden.contains($0.rawValue) }
    }

    var enabledItems: [LatticeHubItem] {
        orderedItems
    }

    var enabledCount: Int { enabledItems.count }
    var visibleCount: Int { visibleItems.count }
    var hiddenCount: Int { hiddenItems.count }

    private var orderedItems: [LatticeHubItem] {
        PanelLayout.itemOrder(LatticeHubItem.self, key: DefaultsKey.quickLauncherItemOrder)
            .filter { $0.isAvailable() }
    }

    var itemOrderBinding: Binding<[LatticeHubItem]> {
        Binding {
            self.orderedItems
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.quickLauncherItemOrder)
            self.objectWillChange.send()
        }
    }

    func setHidden(_ item: LatticeHubItem, _ hidden: Bool) {
        var ids = QuickToolsSupport.hiddenIDs(from: hiddenItemsRaw)
        if hidden {
            ids.insert(item.rawValue)
            if editingOptionsItem == item { editingOptionsItem = nil }
        } else {
            ids.remove(item.rawValue)
        }
        hiddenItemsRaw = QuickToolsSupport.serializeHiddenIDs(ids)
        UserDefaults.standard.set(hiddenItemsRaw, forKey: DefaultsKey.quickLauncherHiddenItems)
        clampSelection()
    }

    var typeaheadBuffer = ""
    var typeaheadTimestamp: TimeInterval = 0
    static let typeaheadCooldown: TimeInterval = 0.8

    // MARK: - Actions

    func activateSelection() {
        guard let selectedIndex, visibleItems.indices.contains(selectedIndex) else { return }
        run(visibleItems[selectedIndex])
    }

    func activate(at index: Int) {
        guard visibleItems.indices.contains(index) else { return }
        run(visibleItems[index])
    }

    func moveSelection(_ direction: QuickToolsSupport.GridDirection,
                       flow: QuickToolsSupport.GridFlow = .rows(columns: LatticeHubService.columns),
                       isIsland: Bool = false) {
        let count = visibleItems.count
        guard count > 0 else { return }
        clearTypeahead()
        guard let current = selectedIndex else {
            selectedIndex = 0
            keyboardIndex = 0
            lastKeyboardActionTimestamp = ProcessInfo.processInfo.systemUptime
            navigationToken = UUID()
            return
        }
        if isIsland {
            selectedIndex = HubStripLayout.railIndex(after: current,
                                                     count: count,
                                                     columns: NotchSupport.toolColumns,
                                                     direction: direction)
        } else {
            selectedIndex = QuickToolsSupport.gridIndex(after: current,
                                                        count: count,
                                                        flow: flow,
                                                        direction: direction)
        }
        keyboardIndex = selectedIndex
        lastKeyboardActionTimestamp = ProcessInfo.processInfo.systemUptime
        navigationToken = UUID()
    }

    func advanceSelection(backwards: Bool = false) {
        let count = visibleItems.count
        guard count > 0 else { return }
        clearTypeahead()
        guard let current = selectedIndex else {
            selectedIndex = backwards ? count - 1 : 0
            keyboardIndex = selectedIndex
            lastKeyboardActionTimestamp = ProcessInfo.processInfo.systemUptime
            navigationToken = UUID()
            return
        }
        if backwards {
            selectedIndex = (current - 1 + count) % count
        } else {
            selectedIndex = (current + 1) % count
        }
        keyboardIndex = selectedIndex
        lastKeyboardActionTimestamp = ProcessInfo.processInfo.systemUptime
        navigationToken = UUID()
    }

    func clearTypeahead() {
        typeaheadBuffer = ""
    }

    func handleTypeahead(_ string: String) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if now - typeaheadTimestamp > Self.typeaheadCooldown {
            typeaheadBuffer = ""
        }
        typeaheadTimestamp = now
        let newBuffer = typeaheadBuffer + string
        let query = newBuffer.lowercased()
        let items = visibleItems
        guard !items.isEmpty else { return false }
        let language = L10n.shared.language

        if newBuffer.count > 1, let firstChar = newBuffer.first, newBuffer.allSatisfy({ $0 == firstChar }) {
            let prefix = String(firstChar).lowercased()
            let matches = items.filter { $0.title(language: language).lowercased().hasPrefix(prefix) }
            if !matches.isEmpty {
                let currentItem = selectedIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }
                let currentIndex = currentItem.flatMap { matches.firstIndex(of: $0) } ?? -1
                let nextIndex = (currentIndex + 1) % matches.count
                let targetItem = matches[nextIndex]
                if let targetIndex = items.firstIndex(of: targetItem) {
                    typeaheadBuffer = newBuffer
                    selectedIndex = targetIndex
                    keyboardIndex = targetIndex
                    lastKeyboardActionTimestamp = now
                    navigationToken = UUID()
                    return true
                }
            }
        }

        if let matchIndex = items.firstIndex(where: {
            $0.title(language: language).lowercased().hasPrefix(query)
        }) {
            typeaheadBuffer = newBuffer
            selectedIndex = matchIndex
            keyboardIndex = matchIndex
            lastKeyboardActionTimestamp = now
            navigationToken = UUID()
            return true
        }

        typeaheadBuffer = newBuffer
        NSSound.beep()
        return true
    }

    func select(_ item: LatticeHubItem) {
        selectedIndex = visibleItems.firstIndex(of: item)
        keyboardIndex = nil
    }

    func run(_ item: LatticeHubItem) {
        guard !isEditing, item.isAvailable() else { return }
        switch item {
        case .screenshot:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                ScreenshotService.shared.capture()
            }
        case .screenRecorder:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                ScreenRecorderService.shared.toggle()
            }
        case .scratchpad:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                ScratchpadService.shared.show()
            }
        case .clipboard:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ClipboardHistoryService.shared.showHistoryWindow()
            }
        case .shelf:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                ShelfService.shared.summon()
            }
        case .textSnippets:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                SnippetLibraryService.shared.show()
            }
        case .aiUsage:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotchService.shared.open(.agents)
            }
        case .watch:
            hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotchService.shared.open(.watch)
            }
        case .windowLayout, .homebrew, .media, .urlCleaner, .uninstaller, .cleaner, .appUpdates, .portManager,
             .killProcess, .wallpaper, .videoDownloader, .recentCaptures, .deviceControls, .system:
            if item == .system {
                SystemNavigationState.shared.reset()
            }
            if isVisible {
                // The floating HUD owns its own opacity transition.
                activeUtility = item
            } else {
                withAnimation(.easeInOut(duration: 0.22)) {
                    activeUtility = item
                }
            }
        }
    }

    func clampSelection() {
        let count = visibleItems.count
        guard count > 0, let current = selectedIndex else {
            return
        }
        selectedIndex = min(current, count - 1)
    }
}
