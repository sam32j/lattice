import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Checking

    /// A source switch changes the answer. Debounces rapid toggles so changing
    /// multiple sources triggers only one scan after the user stops toggling.
    func sourceSelectionDidChange() {
        sourceRefreshWorkItem?.cancel()
        if isChecking {
            sourceRefreshPending = true
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.sourceRefreshWorkItem = nil
            self.check()
        }
        sourceRefreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Scans the enabled sources. `automatic` marks the background pass,
    /// which alone can post a notification and re-arm the schedule.
    func check(automatic: Bool = false) {
        guard AppFeature.appUpdates.isAvailable else { return }
        sourceRefreshWorkItem?.cancel()
        sourceRefreshWorkItem = nil
        if isChecking {
            automaticCheckPending = automaticCheckPending || automatic
            return
        }
        reloadRules()
        let checkedRules = rules
        isChecking = true
        lastError = nil
        checkedAppsCount = 0
        items = []
        if totalAppsCount == 0 {
            let count = InstalledApps.installedApplications().count
            totalAppsCount = count > 0 ? count : 48
        }
        scanGeneration += 1
        let generation = scanGeneration
        let cancellation = AppUpdateCheckCancellation()
        checkCancellation = cancellation
        let includeHomebrewApps = UserDefaults.standard.bool(
            forKey: DefaultsKey.appUpdatesIncludeHomebrewApps)
        let includeAppStore = UserDefaults.standard.bool(forKey: DefaultsKey.appUpdatesIncludeAppStore)
        let includeOnlineCatalog = UserDefaults.standard.bool(
            forKey: DefaultsKey.appUpdatesIncludeOnlineCatalog)
        let country = Locale.current.region?.identifier

        workQueue.async { [weak self] in
            guard let self, !cancellation.isCancelled else { return }
            let apps = AppUpdatesSupport.checkedApps(
                Self.scanInstalledApps(includePublisherFeeds: includeOnlineCatalog, cancellation: cancellation), rules: checkedRules)
            guard !cancellation.isCancelled else { return }
            let packageResult = includeHomebrewApps || includeOnlineCatalog
                ? self.packageManagerFindings(apps: apps, includeUpdates: includeHomebrewApps, cancellation: cancellation)
                : PackageResult(items: [], coveredPaths: [], available: true,
                                onlineCoverageAvailable: true)
            guard !cancellation.isCancelled else { return }

            let coveredPaths = packageResult.coveredPaths
            let storeCandidates = includeAppStore
                ? AppUpdatesSupport.appStoreCandidates(
                    apps: apps, coveredPaths: Set(packageResult.items.compactMap(\.bundlePath)))
                : []
            let onlineCandidates = includeOnlineCatalog
                && packageResult.onlineCoverageAvailable
                ? AppUpdatesSupport.onlineCatalogCandidates(apps: apps, coveredPaths: coveredPaths)
                : []

            let activeApps = apps.filter { app in
                if includeAppStore && (app.isFromAppStore || storeCandidates.contains(where: { $0.path == app.path })) {
                    return true
                }
                if includeHomebrewApps && (coveredPaths.contains(app.path) || packageResult.items.contains { $0.bundlePath == app.path }) {
                    return true
                }
                if includeOnlineCatalog && onlineCandidates.contains(where: { $0.path == app.path }) {
                    return true
                }
                return false
            }
            let total = activeApps.count
            DispatchQueue.main.async {
                self.totalAppsCount = total
                self.checkedAppsCount = max(0, min(total, total / 4))
                UserDefaults.standard.set(total, forKey: "appUpdatesTotalAppsCount")
            }

            let visiblePackageItems = AppUpdatesSupport.visibleItems(packageResult.items, rules: checkedRules)
            for (idx, item) in visiblePackageItems.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.1) { [weak self] in
                    guard let self, self.isChecking, generation == self.scanGeneration else { return }
                    self.appendUpdate(item, rules: checkedRules)
                }
            }
            let os = ProcessInfo.processInfo.operatingSystemVersion
            let operatingSystemVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
            let group = DispatchGroup()
            var storeResult = SourceResult(items: [], available: true)
            var feedResult = SourceResult(items: [], available: true)
            var onlineResult = SourceResult(
                items: [],
                available: !includeOnlineCatalog || packageResult.onlineCoverageAvailable,
                uncheckedApps: includeOnlineCatalog && !packageResult.onlineCoverageAvailable
                    ? AppUpdatesSupport.onlineCatalogCandidates(apps: apps, coveredPaths: coveredPaths)
                    : [])

            group.enter()
            self.storeFindings(for: storeCandidates,
                               country: country,
                               operatingSystemVersion: operatingSystemVersion, cancellation: cancellation) { [weak self] result in
                guard let self else { return }
                storeResult = result
                DispatchQueue.main.async {
                    self.checkedAppsCount = max(self.checkedAppsCount, (total * 3) / 4)
                }
                let visibleStoreItems = AppUpdatesSupport.visibleItems(result.items, rules: checkedRules)
                for (idx, item) in visibleStoreItems.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.1) { [weak self] in
                        guard let self, self.isChecking, generation == self.scanGeneration else { return }
                        self.appendUpdate(item, rules: checkedRules)
                    }
                }
                group.leave()
            }
            if includeOnlineCatalog, onlineResult.available {
                group.enter()
                self.publisherFindings(for: onlineCandidates,
                                       operatingSystemVersion: operatingSystemVersion, cancellation: cancellation) { [weak self] result in
                    guard let self else { return }
                    feedResult = result
                    let visibleFeedItems = AppUpdatesSupport.visibleItems(result.items, rules: checkedRules)
                    for (idx, item) in visibleFeedItems.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.1) { [weak self] in
                            guard let self, self.isChecking, generation == self.scanGeneration else { return }
                            self.appendUpdate(item, rules: checkedRules)
                        }
                    }
                    group.leave()
                }
                group.enter()
                self.onlineCatalogFindings(for: onlineCandidates,
                                           operatingSystemVersion: operatingSystemVersion,
                                           forceRefresh: !automatic, cancellation: cancellation) { [weak self] result in
                    guard let self else { return }
                    onlineResult = result
                    let visibleCatalogItems = AppUpdatesSupport.visibleItems(result.items, rules: checkedRules)
                    for (idx, item) in visibleCatalogItems.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.1) { [weak self] in
                            guard let self, self.isChecking, generation == self.scanGeneration else { return }
                            self.appendUpdate(item, rules: checkedRules)
                        }
                    }
                    group.leave()
                }
            }
            group.notify(queue: self.workQueue) {
                let resolvedFeed = feedResult.resolvingCatalogFallback(
                    answeredBy: onlineResult, candidates: onlineCandidates)
                DispatchQueue.main.async {
                    guard generation == self.scanGeneration, !cancellation.isCancelled else { return }
                    self.checkCancellation = nil
                    self.finishCheck(items: AppUpdatesSupport.merged(packageResult.items,
                                                                     storeResult.items,
                                                                     resolvedFeed.items,
                                                                     onlineResult.items.filter {
                                                                         !resolvedFeed.checkedPaths.contains($0.bundlePath ?? "")
                                                                     }),
                                     packageManagerAvailable: packageResult.available,
                                     onlineCatalogAvailable: onlineResult.available && resolvedFeed.available,
                                     appStoreAvailable: storeResult.available,
                                     uncheckedAppNames: AppUpdatesSupport.uncheckedAppNames(
                                        storeResult.uncheckedApps + resolvedFeed.uncheckedApps + onlineResult.uncheckedApps,
                                        checkedPaths: resolvedFeed.checkedPaths),
                                     uncomparableAppNames: onlineResult.uncomparableAppNames(coveredBy: resolvedFeed),
                                     automatic: automatic)
                }
            }
        }
    }

    func finishCheck(items scannedItems: [AppUpdatesSupport.Item],
                             packageManagerAvailable available: Bool,
                             onlineCatalogAvailable catalogAvailable: Bool,
                             appStoreAvailable storeAvailable: Bool,
                             uncheckedAppNames: [String],
                             uncomparableAppNames: [String],
                             automatic: Bool) {
        // The feature can be switched off in the hub while a scan is in
        // flight; its findings belong to a surface that no longer exists.
        guard AppFeature.appUpdates.isAvailable else {
            isChecking = false
            sourceRefreshPending = false
            automaticCheckPending = false
            return
        }
        let shouldFinishAutomatically = automatic || automaticCheckPending
        automaticCheckPending = false
        if sourceRefreshPending {
            sourceRefreshPending = false
            isChecking = false
            check(automatic: shouldFinishAutomatically)
            return
        }
        allItems = scannedItems
        let newItems = AppUpdatesSupport.visibleItems(scannedItems, rules: rules)
        // What was already announced survives relaunches, unlike knownIDs:
        // otherwise the first background check of every launch would speak up
        // about the same pending update again. Findings that are gone drop out,
        // so an app updating again later is announced again.
        var announced = Self.announcedIDs().intersection(newItems.map(\.id))
        let fresh = newItems.filter { !announced.contains($0.id) }
        selection = AppUpdatesSupport.reconciledSelection(previous: selection,
                                                          knownIDs: knownIDs,
                                                          items: newItems)
        knownIDs = Set(newItems.map(\.id))
        if !items.isEmpty {
            let existingIDs = Set(items.map(\.id))
            let remaining = newItems.filter { !existingIDs.contains($0.id) }
            items = items.filter { item in newItems.contains(where: { $0.id == item.id }) } + remaining
        } else {
            items = newItems
        }
        packageManagerAvailable = available
        onlineCatalogAvailable = catalogAvailable
        appStoreAvailable = storeAvailable
        self.uncheckedAppNames = uncheckedAppNames
        self.uncomparableAppNames = uncomparableAppNames
        hasCheckedThisSession = true
        isChecking = false
        totalAppsCount = max(totalAppsCount, newItems.count)
        checkedAppsCount = totalAppsCount
        installingItemIDs.formIntersection(newItems.map(\.id))
        let now = Date()
        lastCheck = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: DefaultsKey.appUpdatesLastCheck)
        UserDefaults.standard.set(newItems.count, forKey: DefaultsKey.appUpdatesLastCount)
        if shouldFinishAutomatically {
            if notifyIfWanted(freshCount: fresh.count, total: newItems.count) {
                announced = Set(newItems.map(\.id))
            }
            scheduleNext()
        }
        Self.saveAnnouncedIDs(announced)
    }

    func appendUpdate(_ item: AppUpdatesSupport.Item, rules: [AppUpdatesSupport.UpdateRule]) {
        guard isChecking else { return }
        guard !rules.contains(where: { $0.hides(item) }) else { return }
        if !items.contains(where: { $0.id == item.id || ($0.bundleID != nil && $0.bundleID == item.bundleID) }) {
            items.append(item)
            if item.isSelectable {
                selection.insert(item.id)
            }
        }
    }

    /// Only the background pass speaks up, and only about apps the person has
    /// not been told about yet, so a Mac with one stubborn pending update
    /// stays quiet after the first notice. True when a notice went out.
    func notifyIfWanted(freshCount: Int, total: Int) -> Bool {
        guard freshCount > 0,
              UserDefaults.standard.bool(forKey: DefaultsKey.appUpdatesNotify) else { return false }
        let strings = FeatureStrings.appUpdates(L10n.shared.language)
        let body = total == 1
            ? strings.notificationBodyOne
            : String(format: strings.notificationBodyFormat, "\(total)")
        Notifier.post(title: strings.pageTitle, body: body)
        return true
    }

    static func announcedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: DefaultsKey.appUpdatesNotifiedIDs) ?? [])
    }

    static func saveAnnouncedIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(ids.sorted(), forKey: DefaultsKey.appUpdatesNotifiedIDs)
    }

}
