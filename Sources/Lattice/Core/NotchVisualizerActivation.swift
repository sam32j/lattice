import Combine
import Foundation

/// One explicit visualizer enable owns one cancellable system-audio request.
final class NotchVisualizerActivation: ObservableObject {
    @Published private(set) var requesting = false
    @Published private(set) var failed = false
    private let request: (@escaping (SystemAudioAccessResult) -> Void) -> FeatureWorkCancellation
    private let verify: (@escaping (SystemAudioAuthorizationStatus) -> Void) -> FeatureWorkCancellation
    private let openSettings: () -> Void
    private var waitingForSettings = false
    private let canEnable: () -> Bool
    private let apply: (Bool) -> Void
    private var pending: UUID?
    private var work: FeatureWorkCancellation?

    init(request: @escaping (@escaping (SystemAudioAccessResult) -> Void) -> FeatureWorkCancellation,
         verify: @escaping (@escaping (SystemAudioAuthorizationStatus) -> Void) -> FeatureWorkCancellation,
         openSettings: @escaping () -> Void,
         canEnable: @escaping () -> Bool, apply: @escaping (Bool) -> Void) {
        self.request = request; self.verify = verify; self.openSettings = openSettings; self.canEnable = canEnable; self.apply = apply
    }

    func setEnabled(_ value: Bool) {
        cancel()
        failed = false
        guard value else { apply(false); return }
        guard canEnable() else { apply(false); return }
        apply(false)
        let id = UUID()
        pending = id
        requesting = true
        work = request { [weak self] result in
            guard let self, self.pending == id else { return }
            self.requesting = false
            self.failed = result != .granted
            self.pending = nil
            if result == .granted, self.canEnable() { self.apply(true) }
        }
    }

    /// Only the recovery button may navigate away or arm Settings-return activation.
    func openSettingsForRecovery() {
        guard failed, canEnable() else { return }
        cancel()
        pending = UUID()
        waitingForSettings = true
        openSettings()
    }

    func returnedToApplication() {
        guard waitingForSettings, let id = pending else { return }
        waitingForSettings = false
        requesting = true
        work = verify { [weak self] status in
            guard let self, self.pending == id else { return }
            self.pending = nil
            self.requesting = false
            self.failed = status != .granted
            if status == .granted, self.canEnable() { self.apply(true) }
        }
    }

    func cancel() {
        pending = nil
        waitingForSettings = false
        requesting = false
        work?.cancel()
        work = nil
    }

    static func reconcileParents(islandEnabled: Bool, musicEnabled: Bool,
                                 in defaults: UserDefaults = .standard) -> Bool {
        guard !islandEnabled || !musicEnabled else { return false }
        disableForPermissionReset(in: defaults)
        return true
    }

    static func reconcileAuthorization(_ status: SystemAudioAuthorizationStatus,
                                       in defaults: UserDefaults = .standard) {
        if status != .granted { disableForPermissionReset(in: defaults) }
    }

    static func disableForPermissionReset(in defaults: UserDefaults = .standard) {
        for key in [DefaultsKey.notchLiveEqualizer, AppFeature.notchLiveEqualizer.availabilityKey]
            where defaults.object(forKey: key) as? Bool != false {
            defaults.set(false, forKey: key)
        }
        if DeferredPermissionActivation.pendingFeature(in: defaults) == .notchLiveEqualizer {
            DeferredPermissionActivation.clear(in: defaults)
        }
    }
}
