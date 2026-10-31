import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Acting on the list

    var selectedCount: Int { selection.count }
    var selectableCount: Int { items.filter(\.isSelectable).count }

    func selectAll() {
        selection = Set(items.filter(\.isSelectable).map(\.id))
    }

    func selectNone() {
        selection = []
    }

    func toggle(_ item: AppUpdatesSupport.Item) {
        guard item.isSelectable, items.contains(item) else { return }
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
    }

    /// Updates what the person ticked: the package manager installs its share
    /// in one command, and the store apps hand off to the App Store, which is
    /// as far as any app can go there.
    func updateSelected() {
        guard AppFeature.appUpdates.isAvailable else { return }
        let tokens = AppUpdatesSupport.tokens(in: items, selection: selection)
        if !tokens.isEmpty {
            startUpgrade(tokens)
        }
        if let page = AppUpdatesSupport.singleStorePage(in: items, selection: selection),
           let url = URL(string: page) {
            handOff(url)
        } else if AppUpdatesSupport.hasStoreSelection(in: items, selection: selection) {
            openAppStoreUpdates()
        }
    }

    func update(_ item: AppUpdatesSupport.Item) {
        guard AppFeature.appUpdates.isAvailable else { return }
        guard items.contains(item) else { return }
        switch item.source {
        case .packageManager:
            guard let token = item.token else { return }
            startUpgrade([token])
        case .appStore:
            if let page = item.storePage, let url = URL(string: page) {
                handOff(url)
            } else {
                openAppStoreUpdates()
            }
        case .onlineCatalog:
            guard let path = item.bundlePath else { return }
            handOff(URL(fileURLWithPath: path))
        }
    }

    func openAppStoreUpdates() {
        guard AppFeature.appUpdates.isAvailable else { return }
        guard let url = URL(string: "macappstore://showUpdatesPage") else { return }
        handOff(url)
    }

    /// The destination installs its own update, so open it and tell the truth
    /// again the moment the person is back. Opening runs off the main thread,
    /// since launching a large app can take a while.
    func handOff(_ url: URL) {
        guard AppFeature.appUpdates.isAvailable else { return }
        let request = UUID()
        pendingUpdateHandoffs.insert(request)
        NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard error != nil else { return }
            DispatchQueue.main.async { self?.pendingUpdateHandoffs.remove(request) }
        }
    }

    /// Watches the upgrade to its end and re-reads the list, so a row leaves
    /// on its own instead of waiting for someone to press Check now. The
    /// observer lives only for that one operation.
    func startUpgrade(_ tokens: [String]) {
        guard AppFeature.appUpdates.isAvailable else { return }
        upgradeObserver = HomebrewManager.shared.$operationStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let status, status.result != .running else { return }
                self?.upgradeObserver = nil
                guard status.result == .succeeded else { return }
                self?.check()
            }
        HomebrewManager.shared.upgradeCasks(tokens, owner: .appUpdates)
    }

    func reveal(_ item: AppUpdatesSupport.Item) {
        guard let path = item.bundlePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// What a surface calls when it appears. It scans again when the answer
    /// could have changed behind the app's back: nothing read yet in this
    /// process, an update just finished elsewhere, or the last answer is
    /// simply old. Otherwise reopening the panel costs nothing.
    func checkIfNeeded() {
        reloadRules()
        guard AppUpdatesSupport.shouldRecheck(hasCheckedThisSession: hasCheckedThisSession,
                                              handoffPending: updateHandoffPending,
                                              lastCheck: lastCheck,
                                              now: Date()) else { return }
        check()
    }

    /// Called when the app comes back to the front. Returning from an updater
    /// is the moment the list is most likely to be stale, and the window the
    /// person left behind is buried because this app has no Dock icon.
    func applicationBecameActive() {
        guard updateHandoffPending else { return }
        checkIfNeeded()
    }

    /// True while the app should reopen the window the update hand-off left
    /// behind. Reading it clears the flag, so the window is restored once.
    func consumeUpdateHandoffReturn() -> Bool {
        guard updateHandoffPending else { return false }
        pendingUpdateHandoffs.removeAll()
        return true
    }

}
