import Foundation

/// One check owns its subprocesses and requests. Registering after cancellation
/// immediately cancels the resource, closing the launch-versus-disable race.
final class FeatureWorkCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var actions: [UUID: () -> Void] = [:]

    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    @discardableResult
    func register(_ action: @escaping () -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        if cancelled {
            lock.unlock()
            action()
        } else {
            actions[id] = action
            lock.unlock()
        }
        return id
    }

    func remove(_ id: UUID) {
        lock.lock()
        actions.removeValue(forKey: id)
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        guard !cancelled else { lock.unlock(); return }
        cancelled = true
        let pending = Array(actions.values)
        actions.removeAll()
        lock.unlock()
        pending.forEach { $0() }
    }
}
