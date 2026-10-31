import Foundation

extension KillProcessService {
    func hasProtectedAction(for feature: AppFeature) -> Bool {
        feature == .killProcess ? !activeActionOwners.isEmpty : (activeActionOwners[feature] ?? 0) > 0
    }

    /// A committed process action can wait in native authorization. Hold both
    /// its requesting owner and Kill Process until that execution returns.
    func beginProtectedAction(_ owner: AppFeature) {
        activeActionOwners[owner, default: 0] += 1
    }

    func endProtectedAction(_ owner: AppFeature) {
        DispatchQueue.main.async {
            let remaining = (self.activeActionOwners[owner] ?? 0) - 1
            if remaining > 0 { self.activeActionOwners[owner] = remaining }
            else { self.activeActionOwners.removeValue(forKey: owner) }
        }
    }
}
