import Foundation

/// Accessed on the owning service's main thread. Handles are thread-safe so
/// disablement can cancel work queued or running on a background executor.
final class FeatureWorkRegistry {
    private var owners: [AppFeature: FeatureWorkCancellation] = [:]

    func begin(owner: AppFeature, isAvailable: (AppFeature) -> Bool) -> FeatureWorkCancellation? {
        guard isAvailable(owner) else { return nil }
        if let existing = owners[owner] { return existing }
        let work = FeatureWorkCancellation()
        owners[owner] = work
        return work
    }

    func cancelUnavailable(isAvailable: (AppFeature) -> Bool) {
        for owner in Array(owners.keys) where !isAvailable(owner) {
            owners.removeValue(forKey: owner)?.cancel()
        }
    }
}
