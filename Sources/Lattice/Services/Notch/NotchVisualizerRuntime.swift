import Foundation

/// Parent changes reconcile the child even when its Settings view is absent.
enum NotchVisualizerRuntime {
    private static var verification: FeatureWorkCancellation?
    private static var verificationID: UUID?

    private static func cancelVerification() {
        verificationID = nil
        verification?.cancel()
        verification = nil
    }

    @discardableResult
    static func reconcileParents() -> Bool {
        let parentOff = NotchVisualizerActivation.reconcileParents(
            islandEnabled: NotchSupport.isEnabled(), musicEnabled: NotchSupport.modules().contains(.music))
        if parentOff {
            cancelVerification()
            SystemAudioRecordingAccess.cancelPending()
            NotchAudioLevelService.shared.syncWithPreferences()
        }
        return parentOff
    }

    static func syncWithPreferences() {
        guard !reconcileParents() else { return }
        guard UserDefaults.standard.bool(forKey: DefaultsKey.notchLiveEqualizer),
              AppFeature.notchLiveEqualizer.isAvailable else {
            cancelVerification()
            NotchAudioLevelService.shared.syncWithPreferences()
            return
        }
        guard verificationID == nil else { return }
        let id = UUID()
        verificationID = id
        verification = SystemAudioRecordingAccess.check { status in
            guard verificationID == id else { return }
            verificationID = nil
            verification = nil
            guard !reconcileParents() else { return }
            NotchVisualizerActivation.reconcileAuthorization(status)
            NotchAudioLevelService.shared.syncWithPreferences()
        }
    }
}
