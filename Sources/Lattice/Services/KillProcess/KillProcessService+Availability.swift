import Foundation

extension KillProcessService {
    func syncWithFeatures() {
        readWork.cancelUnavailable(isAvailable: { $0.isAvailable && AppFeature.killProcess.isAvailable })
        guard !AppFeature.killProcess.isAvailable else { return }
        cancelPendingRestart()
        entries = []
        isRefreshing = false
        hasLoadedOnce = false
        lastRefresh = 0
    }
}
