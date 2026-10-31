import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - App Store source

    func storeFindings(for candidates: [AppUpdatesSupport.InstalledApp],
                               country: String?,
                               operatingSystemVersion: String,
                               cancellation: AppUpdateCheckCancellation? = nil,
                               completion: @escaping (SourceResult) -> Void) {
        storeEntries(for: candidates, country: country, preferStoreIDs: true, cancellation: cancellation) { entries in
            let missing = candidates.filter { entries[$0.bundleID] == nil && $0.storeID != nil }
            self.storeEntries(for: missing, country: country, preferStoreIDs: false, cancellation: cancellation) { fallback in
                let merged = entries.merging(fallback) { first, _ in first }
                completion(SourceResult(
                    items: AppUpdatesSupport.appStoreUpdates(apps: candidates,
                                                            storeVersions: merged,
                                                            operatingSystemVersion: operatingSystemVersion),
                    available: AppUpdatesSupport.hasStoreCoverage(bundleIDs: candidates.map(\.bundleID),
                                                                 entries: merged),
                    uncheckedApps: candidates.filter { merged[$0.bundleID] == nil }))
            }
        }
    }

    func storeEntries(for candidates: [AppUpdatesSupport.InstalledApp],
                              country: String?, preferStoreIDs: Bool,
                              cancellation: AppUpdateCheckCancellation? = nil,
                              completion: @escaping ([String: AppUpdatesSupport.StoreEntry]) -> Void) {
        guard !candidates.isEmpty, cancellation?.isCancelled != true else {
            completion([:])
            return
        }
        let groups = Dictionary(grouping: candidates) { preferStoreIDs && $0.storeID != nil }
        var merged: [String: AppUpdatesSupport.StoreEntry] = [:]
        let group = DispatchGroup()
        let lock = NSLock()

        for (useIDs, apps) in groups {
            for start in stride(from: 0, to: apps.count, by: AppUpdatesSupport.storeLookupBatchSize) {
                let batch = Array(apps[start..<min(start + AppUpdatesSupport.storeLookupBatchSize, apps.count)])
                let lookup = useIDs
                    ? AppUpdatesSupport.storeIDLookupURL(ids: batch.compactMap(\.storeID), country: country)
                    : AppUpdatesSupport.storeLookupURL(bundleIDs: batch.map(\.bundleID), country: country)
                guard let url = lookup else { continue }
                group.enter()
                let task = lookupSession.dataTask(with: url) { data, response, error in
                    defer { group.leave() }
                    let body = error == nil ? data : nil
                    let statusCode = (response as? HTTPURLResponse)?.statusCode
                    let entries = useIDs
                        ? AppUpdatesSupport.storeMetadataResponse(body, statusCode: statusCode)
                        : AppUpdatesSupport.storeLookupResponse(body, statusCode: statusCode)
                    lock.lock()
                    merged.merge(entries) { _, new in new }
                    lock.unlock()
                }
                cancellation?.register { [weak task] in task?.cancel() }
                task.resume()
            }
        }

        group.notify(queue: workQueue) { completion(merged) }
    }

}
