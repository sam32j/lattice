import CoreGraphics
import Foundation

/// Serializes tap creation with revocation, including dedicated input threads.
/// There is intentionally no resume API: cached TCC grants are unsafe after a
/// reset, even when tccutil reports a partial failure. A new process starts fresh.
final class InputTapGate<Port> {
    private let lock = NSRecursiveLock()
    private let resetLock = NSRecursiveLock()
    private var blocked = false
    private var ports: [Port] = []
    private let isValid: (Port) -> Bool
    private let invalidate: (Port) -> Void

    init(isValid: @escaping (Port) -> Bool, invalidate: @escaping (Port) -> Void) {
        self.isValid = isValid
        self.invalidate = invalidate
    }

    var isBlocked: Bool { lock.withLock { blocked } }

    func create(_ operation: () -> Port?) -> Port? {
        lock.withLock {
            guard !blocked else { return nil }
            // Owners still invalidate their own ports during ordinary teardown.
            // Drop those references rather than accumulating retired handles.
            ports.removeAll { !isValid($0) }
            guard let port = operation() else { return nil }
            ports.append(port)
            return port
        }
    }

    func setEnabled(_ enabled: Bool, operation: () -> Void) {
        lock.withLock {
            guard !enabled || !blocked else { return }
            operation()
        }
    }

    func blockUntilRestart() {
        resetLock.withLock {
            let stopped: [Port] = lock.withLock {
                blocked = true
                let stopped = ports
                ports.removeAll()
                return stopped
            }
            // Disable synchronously before any permission is revoked. Invalidation
            // also covers taps missing from a service's manual suspension list.
            for port in stopped where isValid(port) { invalidate(port) }
        }
    }
}

/// The only production boundary allowed to create or rearm a native event tap.
enum InputEventTap {
    private static let gate = InputTapGate<CFMachPort>(
        isValid: { CFMachPortIsValid($0) },
        invalidate: {
            CGEvent.tapEnable(tap: $0, enable: false)
            CFMachPortInvalidate($0)
        })

    static var isBlocked: Bool { gate.isBlocked }

    static func create(tap: CGEventTapLocation, place: CGEventTapPlacement,
                       options: CGEventTapOptions, eventsOfInterest: CGEventMask,
                       callback: CGEventTapCallBack, userInfo: UnsafeMutableRawPointer?) -> CFMachPort? {
        gate.create {
            CGEvent.tapCreate(tap: tap, place: place, options: options,
                              eventsOfInterest: eventsOfInterest,
                              callback: callback, userInfo: userInfo)
        }
    }

    static func enable(tap: CFMachPort, enable: Bool) {
        gate.setEnabled(enable) { CGEvent.tapEnable(tap: tap, enable: enable) }
    }

    static func blockUntilRestart() { gate.blockUntilRestart() }
}
