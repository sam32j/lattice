import Foundation

extension HomebrewManager {
    func syncWithFeatures() {
        readWork.cancelUnavailable(isAvailable: { $0.isAvailable })
        if let request = installedRead, !request.owner.isAvailable {
            installedRead = nil
            isLoadingInstalled = false
        }
        if let request = outdatedRead, !request.owner.isAvailable {
            clearOutdatedRead(owner: request.owner)
        }
        if operation == nil, let owner = operationOwner, !owner.isAvailable {
            completedOperationCleanup?.cancel()
            completedOperationCleanup = nil
            operationStatus = nil
            terminalFallbackCommand = nil
            log = ""
            operationOwner = nil
        }
        if !AppFeature.homebrew.isAvailable {
            trustRead = nil
            isTrustingTap = false
            installed = []
            searchResults = []
            selectedPackage = nil
            outdatedPackagesByID = [:]
            popularityCache = [:]
            popularityLoads = []
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

    func clearOutdatedRead(owner: AppFeature) {
        guard outdatedRead == nil || outdatedRead?.owner == owner else { return }
        outdatedRead = nil
        outdatedGeneration += 1
        outdatedPackagesByID = [:]
        isLoadingOutdated = false
    }
}
