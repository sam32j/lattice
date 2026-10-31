import Foundation

/// The runtime enforces the same restriction as the visible page switch.
/// Shared package work only holds the owner that requested that operation.
enum FeatureMutationGuard {
    static func isBusy(_ feature: AppFeature) -> Bool {
        switch feature {
        case .cleaner: return JunkCleaner.shared.phase == .cleaning
        case .uninstaller: return AppUninstaller.shared.isRemoving
        case .killProcess, .portManager:
            return KillProcessService.shared.hasProtectedAction(for: feature)
        case .homebrew, .appUpdates:
            let brew = HomebrewManager.shared
            return (brew.operation != nil && brew.operationOwner == feature)
                || (feature == .homebrew && brew.isTrustingTap)
        default: return false
        }
    }
}
