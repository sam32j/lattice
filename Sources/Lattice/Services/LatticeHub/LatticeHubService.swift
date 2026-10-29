// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The central controller for Lattice Hub: presents either a floating HUD
/// (summoned via ⌃⌘V or anchored below the menu bar) or coordinates with the
/// Dynamic Island.
final class LatticeHubService: ObservableObject {
    static let shared = LatticeHubService()
    static let columns = 3

    @Published private(set) var shortcutRegistrationFailed = false
    @Published var isEditing = false
    @Published var editingOptionsItem: LatticeHubItem?
    @Published var activeUtility: LatticeHubItem?
    @Published var selectedIndex: Int?
    @Published var keyboardIndex: Int?
    @Published var presentationID = UUID()
    @Published var hiddenItemsRaw: String = UserDefaults.standard.string(
        forKey: DefaultsKey.quickLauncherHiddenItems) ?? ""

    private let hotkey = QuickToolHotkey(id: 14)
    var panel: NSPanel?
    var keyMonitor: Any?
    var localClickMonitor: Any?
    var outsideClickMonitor: Any?
    var activationObserver: NSObjectProtocol?

    private init() {
        hotkey.onPress = { [weak self] in self?.toggle() }
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

    // MARK: - Presentation

    func toggle() {
        if isVisible {
            hide()
            return
        }
        if shouldRouteToIsland() {
            if NotchService.shared.openQuickPanel(toggle: true) { return }
        }
        show()
    }

    func show(anchoredBelow anchor: NSRect? = nil) {
        if anchor == nil && shouldRouteToIsland() {
            if NotchService.shared.openQuickPanel() {
                if isVisible { hide() }
                return
            }
        }
        (NSApp.delegate as? AppDelegate)?.closePopover()
        if NotchService.shared.expanded, NotchService.shared.selected == .tools {
            NotchService.shared.collapse()
        }
        let panel = ensurePanel()
        prepareForPresentation()
        position(panel, anchoredBelow: anchor)
        installMonitors(for: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.13
            panel.animator().alphaValue = 1
        }
    }

    private func shouldRouteToIsland() -> Bool {
        guard LauncherShortcutTarget.selected(in: .standard) == .island,
              NotchSupport.routesQuickPanel() else {
            return false
        }
        return NSMouseInRect(NSEvent.mouseLocation, NotchService.shared.geometry.screen, false)
    }

    func prepareForPresentation() {
        refreshAvailability()
        presentationID = UUID()
        isEditing = false
        editingOptionsItem = nil
        selectedIndex = visibleItems.isEmpty ? nil : 0
        keyboardIndex = selectedIndex
    }

    func refreshAvailability() {
        if let activeUtility, !activeUtility.isAvailable() { self.activeUtility = nil }
        if let editingOptionsItem, !editingOptionsItem.isAvailable() { self.editingOptionsItem = nil }
        clampSelection()
    }

    func hide() {
        if NotchService.shared.expanded, NotchService.shared.selected == .tools { NotchService.shared.collapse() }
        removeMonitors()
        isEditing = false
        editingOptionsItem = nil
        activeUtility = nil
        panel?.orderOut(nil)
    }

    func closeUtility() {
        activeUtility = nil
    }

    func refocusAfterModal() {
        if NotchService.shared.expanded, NotchService.shared.selected == .tools {
            NotchService.shared.presentationWindow?.makeKey(); return
        }
        guard let panel, panel.isVisible else { return }
        panel.makeKey()
    }

    var dismissesOnOutsideInteraction: Bool {
        activeUtility == nil && NSApp.modalWindow == nil
    }

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
                       flow: QuickToolsSupport.GridFlow = .rows(columns: LatticeHubService.columns)) {
        let count = visibleItems.count
        guard count > 0 else { return }
        selectedIndex = QuickToolsSupport.gridIndex(after: selectedIndex ?? 0,
                                                    count: count,
                                                    flow: flow,
                                                    direction: direction)
        keyboardIndex = selectedIndex
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
        case .cameraPreview:
            let embedded = CameraPreviewService.shared.showInNotchIfEnabled()
            hide()
            if !embedded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    CameraPreviewService.shared.show()
                }
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
        case .windowLayout, .homebrew, .media, .urlCleaner, .uninstaller, .cleaner, .appUpdates, .portManager:
            activeUtility = item
        }
    }

    func clampSelection() {
        let count = visibleItems.count
        guard count > 0 else {
            selectedIndex = nil
            return
        }
        selectedIndex = min(selectedIndex ?? 0, count - 1)
    }
}
