import Foundation

extension HomebrewManager {
    func syncWithFeatures() {
        readWork.cancelUnavailable(isAvailable: { $0.isAvailable })
        if operation == nil, let owner = operationOwner, !owner.isAvailable {
            completedOperationCleanup?.cancel()
            completedOperationCleanup = nil
            operationStatus = nil
            terminalFallbackCommand = nil
            log = ""
            operationOwner = nil
        }
        if !AppFeature.homebrew.isAvailable {
            installed = []
            searchResults = []
            selectedPackage = nil
            outdatedPackagesByID = [:]
            popularityCache = [:]
            popularityLoads = []
            isLoadingInstalled = false
            isLoadingOutdated = false
            isSearching = false
            isLoadingDetails = false
            isLoadingPopularity = false
            clearUntrustedTap()
        }
        if !AppFeature.uninstaller.isAvailable {
            let pending = ownershipLoads.values.flatMap { $0 }
            ownershipLoads = [:]
            installedCaskRecords = []
            installedCaskRecordsFetchedAt = nil
            pending.forEach { $0(nil) }
        }
    }
}
