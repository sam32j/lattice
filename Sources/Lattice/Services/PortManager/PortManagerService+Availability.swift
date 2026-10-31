import Foundation

extension PortManagerService {
    func syncWithFeatures() {
        guard !AppFeature.portManager.isAvailable else { return }
        readWork.cancelUnavailable(isAvailable: { $0.isAvailable })
        entries = []
        isRefreshing = false
        hasLoadedOnce = false
        refreshFailed = false
    }
}
