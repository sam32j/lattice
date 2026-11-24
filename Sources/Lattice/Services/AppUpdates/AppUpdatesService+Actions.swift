import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Acting on the list

    var selectedCount: Int { selection.count }

    func selectAll() {
        selection = Set(items.filter(\.isSelectable).map(\.id))
    }

    func toggle(_ item: AppUpdatesSupport.Item) {
        guard item.isSelectable, items.contains(item) else { return }
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
    }

    func update(_ item: AppUpdatesSupport.Item) {
        guard AppFeature.appUpdates.isAvailable else { return }
        guard items.contains(item) else { return }
        switch item.source {
        case .packageManager:
            guard let token = item.token else { return }
            installingItemIDs.insert(item.id)
            startUpgrade([token])
        case .appStore:
            if let page = item.storePage, let url = URL(string: page) {
                handedOffItemIDs.insert(item.id)
                handOff(url)
            } else {
                openAppStoreUpdates()
            }
        case .onlineCatalog:
            guard let path = item.bundlePath else { return }
            handedOffItemIDs.insert(item.id)
            handOff(URL(fileURLWithPath: path))
        }
    }

    func openAppStoreUpdates() {
        guard AppFeature.appUpdates.isAvailable else { return }
        guard let url = URL(string: "macappstore://showUpdatesPage") else { return }
        // The store may update any of its apps from there.
        handedOffItemIDs.formUnion(items.filter { $0.source == .appStore }.map(\.id))
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
        let matchingIDs = items.filter { item in
            item.token.map { tokens.contains($0) } ?? false
        }.map(\.id)
        installingItemIDs.formUnion(matchingIDs)
        upgradeObserver = HomebrewManager.shared.$operationStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let status, status.result != .running else { return }
                self?.upgradeObserver = nil
                self?.installingItemIDs.subtract(matchingIDs)
                guard status.result == .succeeded else { return }
                // Only these casks changed; the rest of the list still holds.
                self?.dropUpdated(Set(matchingIDs))
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
        // Back from an updater: only the apps handed off are read again.
        let handedOff = !handedOffItemIDs.isEmpty
        if handedOff { refreshHandedOff() }
        guard AppUpdatesSupport.shouldRecheck(hasCheckedThisSession: hasCheckedThisSession,
                                              handoffPending: updateHandoffPending && !handedOff,
                                              lastCheck: lastCheck,
                                              now: Date()) else { return }
        check()
    }

    /// Re-reads each handed-off app's version from its bundle and drops the
    /// rows now current. One still behind stays, and is read again on the
    /// next return, since an app may finish updating after relaunching.
    func refreshHandedOff() {
        let ids = handedOffItemIDs
        let current = items.filter { ids.contains($0.id) && Self.isNowCurrent($0) }.map(\.id)
        let stillListed = Set(items.map(\.id))
        handedOffItemIDs = ids.intersection(stillListed).subtracting(current)
        dropUpdated(Set(current))
    }

    /// Takes rows that were updated out of the list, without a scan.
    func dropUpdated(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        allItems.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        knownIDs.subtract(ids)
        installingItemIDs.subtract(ids)
        UserDefaults.standard.set(items.count, forKey: DefaultsKey.appUpdatesLastCount)
    }

    /// Whether the app a row stands for now reports the version the row
    /// offered, read from its Info.plist so a replaced bundle is not served
    /// from Bundle's cache.
    static func isNowCurrent(_ item: AppUpdatesSupport.Item) -> Bool {
        guard let path = item.bundlePath,
              let info = NSDictionary(contentsOf: URL(fileURLWithPath: path)
                .appendingPathComponent("Contents/Info.plist")) as? [String: Any],
              let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String)
        else { return false }
        return !AppUpdatesSupport.isNewer(item.latestVersion, than: version)
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
