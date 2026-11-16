import Foundation

extension KillProcessService {
    func syncWithFeatures() {
        readWork.cancelUnavailable(isAvailable: { $0.isAvailable && AppFeature.killProcess.isAvailable })
        guard !AppFeature.killProcess.isAvailable else { return }
        cancelPendingRestart(relaunched: false)
        entries = []
        items = []
        isRefreshing = false
        hasLoadedOnce = false
        lastRefresh = 0
    }
}
