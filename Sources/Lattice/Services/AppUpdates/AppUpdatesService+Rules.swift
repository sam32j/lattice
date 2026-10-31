import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Update rules

    func skipVersion(_ item: AppUpdatesSupport.Item) {
        guard !AppUpdatesSupport.isUncomparable(item.latestVersion) else { return }
        setRule(for: item, version: item.latestVersion)
    }

    func excludeApp(_ item: AppUpdatesSupport.Item) {
        setRule(for: item, version: nil)
    }

    /// Excludes an app straight from its bundle, so one that is not in the list
    /// (up to date, or never matched by a source) can still be left out.
    func addExclusion(appAt url: URL) {
        guard !isChecking,
              let app = Self.scannedApp(at: url, includePublisherFeeds: false) else { return }
        storeRule(bundleID: app.bundleID, name: app.name, version: nil)
    }

    func setRule(for item: AppUpdatesSupport.Item, version: String?) {
        guard !isChecking, let bundleID = item.bundleID, items.contains(item) else { return }
        storeRule(bundleID: bundleID, name: item.name, version: version)
    }

    func storeRule(bundleID: String, name: String, version: String?) {
        // Same shape `decodedRules` accepts, so a rule saved now survives a reload.
        guard !bundleID.isEmpty, bundleID.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !bundleID.contains("/"),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let rule = AppUpdatesSupport.UpdateRule(bundleID: bundleID, name: name, version: version)
        saveRules(rules.filter { $0.bundleID != bundleID } + [rule])
    }

    func removeRule(_ rule: AppUpdatesSupport.UpdateRule) {
        guard !isChecking, rules.contains(rule) else { return }
        saveRules(rules.filter { $0.id != rule.id })
        // An excluded app was not queried in later scans. Do not invent a current
        // result or launch a full scan just to remove its rule; Check now remains available.
        if rule.version == nil { hasCheckedThisSession = false }
    }

    func saveRules(_ newRules: [AppUpdatesSupport.UpdateRule]) {
        guard let raw = AppUpdatesSupport.encodedRules(newRules) else { return }
        rules = newRules
        UserDefaults.standard.set(raw, forKey: DefaultsKey.appUpdatesRules)
        applyRules()
    }

    /// Settings restore and reset use the same preference as the panel.
    func reloadRules() {
        let restored = AppUpdatesSupport.decodedRules(
            UserDefaults.standard.string(forKey: DefaultsKey.appUpdatesRules))
        guard restored != rules else { return }
        rules = restored
        hasCheckedThisSession = false
        if isChecking { sourceRefreshPending = true }
        applyRules()
    }

    func applyRules() {
        let visible = AppUpdatesSupport.visibleItems(allItems, rules: rules)
        selection = AppUpdatesSupport.reconciledSelection(previous: selection,
                                                          knownIDs: knownIDs, items: visible)
        knownIDs = Set(visible.map(\.id))
        items = visible
        UserDefaults.standard.set(visible.count, forKey: DefaultsKey.appUpdatesLastCount)
        Self.saveAnnouncedIDs(Self.announcedIDs().intersection(knownIDs))
    }

}
