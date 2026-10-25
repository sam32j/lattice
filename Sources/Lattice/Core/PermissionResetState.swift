import Combine

final class PermissionResetState: ObservableObject {
    static let shared = PermissionResetState()
    enum Phase: Equatable { case ready, working, restartRequired, failed }
    @Published private(set) var phase: Phase

    init(phase: Phase = .ready) { self.phase = phase }

    func begin(using reset: (@escaping (Bool) -> Void) -> Void) {
        guard phase == .ready || phase == .failed else { return }
        phase = .working
        reset { [weak self] succeeded in
            guard self?.phase == .working else { return }
            self?.phase = succeeded ? .restartRequired : .failed
        }
    }
}
