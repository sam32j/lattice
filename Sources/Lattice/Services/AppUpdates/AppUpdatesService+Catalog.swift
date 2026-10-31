import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Online catalog source

    struct SourceResult {
        let items: [AppUpdatesSupport.Item]
        let available: Bool
        var checkedPaths: Set<String> = []
        var uncheckedApps: [AppUpdatesSupport.InstalledApp] = []
        var catalogFallbackPaths: Set<String> = []
        var uncomparableApps: [AppUpdatesSupport.InstalledApp] = []

        /// A catalog match whose version cannot be compared still answers for
        /// a missing feed; that app is named for its version instead.
        var answeredPaths: Set<String> { checkedPaths.union(uncomparableApps.map(\.path)) }

        func resolvingCatalogFallback(checkedPaths catalogPaths: Set<String>,
                                      candidates: [AppUpdatesSupport.InstalledApp]) -> SourceResult {
            let missing = catalogFallbackPaths.subtracting(catalogPaths)
            return SourceResult(items: items, available: available && missing.isEmpty,
                                checkedPaths: checkedPaths,
                                uncheckedApps: uncheckedApps + candidates.filter { missing.contains($0.path) })
        }

        /// The feeds, with a missing one answered by whatever the catalog
        /// found for that app, compared or only named.
        func resolvingCatalogFallback(answeredBy catalog: SourceResult,
                                      candidates: [AppUpdatesSupport.InstalledApp]) -> SourceResult {
            resolvingCatalogFallback(checkedPaths: catalog.answeredPaths, candidates: candidates)
        }

        /// The catalog's uncompared apps, less those their own feed compared.
        func uncomparableAppNames(coveredBy feeds: SourceResult) -> [String] {
            AppUpdatesSupport.uncheckedAppNames(uncomparableApps, checkedPaths: feeds.checkedPaths)
        }
    }

    static let onlineCatalogCacheLifetime: TimeInterval = 60 * 60

    func publisherFindings(for candidates: [AppUpdatesSupport.InstalledApp],
                                   operatingSystemVersion: String,
                                   cancellation: AppUpdateCheckCancellation? = nil,
                                   completion: @escaping (SourceResult) -> Void) {
        var grouped: [AppUpdateFeedSupport.Feed: [AppUpdatesSupport.InstalledApp]] = [:]
        for app in candidates {
            if let feed = app.updateFeed { grouped[feed, default: []].append(app) }
        }
        let feeds = Array(grouped)
        var items: [AppUpdatesSupport.Item] = []
        var checkedPaths = Set<String>()
        var uncheckedPaths = Set<String>()
        var catalogFallbackPaths = Set<String>()
        var complete = true
        let deadline = Date().addingTimeInterval(60)
        var kernelBytes = [CChar](repeating: 0, count: 256)
        var kernelSize = kernelBytes.count
        let kernelVersion = sysctlbyname("kern.osrelease", &kernelBytes, &kernelSize, nil, 0) == 0
            ? String(cString: kernelBytes) : ""
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif

        // Four at a time, coalesced by URL, with a ceiling for the whole pass.
        // All accumulated results are confined to workQueue.
        func checkBatch(_ start: Int) {
            guard start < feeds.count, Date() < deadline, cancellation?.isCancelled != true else {
                // A feed the deadline cut off was not checked, so keep its apps named.
                uncheckedPaths.formUnion(feeds[start...].flatMap { $0.value.map(\.path) })
                completion(SourceResult(items: items, available: complete && start >= feeds.count,
                                        checkedPaths: checkedPaths,
                                        uncheckedApps: candidates.filter {
                                            uncheckedPaths.contains($0.path)
                                        }, catalogFallbackPaths: catalogFallbackPaths))
                return
            }
            let end = min(start + 4, feeds.count)
            let group = DispatchGroup()
            for (feed, apps) in feeds[start..<end] {
                group.enter()
                AppUpdateFeedLoader.load(feed.url, cancellation: cancellation) { loadResult in
                    self.workQueue.async {
                        defer { group.leave() }
                        let findings = AppUpdateFeedSupport.findings(
                            loadResult: loadResult, format: feed.format, apps: apps,
                            operatingSystemVersion: operatingSystemVersion,
                            kernelVersion: kernelVersion, architecture: architecture)
                        items.append(contentsOf: findings.items)
                        checkedPaths.formUnion(findings.checkedPaths)
                        uncheckedPaths.formUnion(findings.uncheckedPaths)
                        catalogFallbackPaths.formUnion(findings.catalogFallbackPaths)
                        complete = complete && findings.complete
                    }
                }
            }
            group.notify(queue: self.workQueue) { checkBatch(end) }
        }
        checkBatch(0)
    }

    func onlineCatalogFindings(for candidates: [AppUpdatesSupport.InstalledApp],
                                       operatingSystemVersion: String,
                                       forceRefresh: Bool,
                                       cancellation: AppUpdateCheckCancellation? = nil,
                                       completion: @escaping (SourceResult) -> Void) {
        guard !candidates.isEmpty, cancellation?.isCancelled != true else {
            completion(SourceResult(items: [], available: true))
            return
        }

        let now = Date()
        if !forceRefresh, let cache = onlineCatalogCache {
            let age = now.timeIntervalSince(cache.loadedAt)
            if age >= 0, age < Self.onlineCatalogCacheLifetime {
                completion(onlineResult(candidates: candidates,
                                        catalog: cache.entries,
                                        operatingSystemVersion: operatingSystemVersion))
                return
            }
        }

        var request = URLRequest(url: AppUpdatesSupport.onlineCatalogURL)
        if forceRefresh { request.cachePolicy = .reloadIgnoringLocalCacheData }
        let task = catalogSession.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            self.workQueue.async {
                guard cancellation?.isCancelled != true else {
                    completion(SourceResult(items: [], available: false, uncheckedApps: candidates))
                    return
                }
                guard let entries = AppUpdatesSupport.parseOnlineCatalogResponse(
                    data, statusCode: statusCode) else {
                    completion(SourceResult(items: [], available: false, uncheckedApps: candidates))
                    return
                }
                self.onlineCatalogCache = (Date(), entries)
                completion(self.onlineResult(candidates: candidates,
                                             catalog: entries,
                                             operatingSystemVersion: operatingSystemVersion))
            }
        }
        cancellation?.register { [weak task] in task?.cancel() }
        task.resume()
    }

    func onlineResult(candidates: [AppUpdatesSupport.InstalledApp],
                              catalog: [AppUpdatesSupport.CatalogEntry],
                              operatingSystemVersion: String) -> SourceResult {
        let findings = AppUpdatesSupport.onlineCatalogFindings(
            apps: candidates, catalog: catalog,
            operatingSystemVersion: operatingSystemVersion,
            ignoredTokens: Self.ownPackageTokens)
        return SourceResult(items: findings.items, available: true,
                            checkedPaths: findings.checkedPaths,
                            uncomparableApps: findings.uncomparableApps)
    }

}
