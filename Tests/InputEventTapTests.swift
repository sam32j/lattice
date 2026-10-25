import CoreGraphics
import Foundation

enum InputEventTapTests {
    final class Port {
        var valid = true
        var enabled = true
        var stops = 0
    }

    static func run(_ suite: TestSuite) {
        let gate = InputTapGate<Port>(isValid: { $0.valid }, invalidate: {
            $0.enabled = false
            $0.valid = false
            $0.stops += 1
        })
        let port = Port()
        suite.expect(gate.create { port } === port, "ordinary input taps can start before reset")
        gate.blockUntilRestart()
        suite.expect(gate.isBlocked && !port.valid && !port.enabled && port.stops == 1,
                     "reset synchronously disables and invalidates every tracked tap")
        var createdAfterReset = false
        let denied = gate.create { createdAfterReset = true; return Port() }
        suite.expect(denied == nil && !createdAfterReset,
                     "reset rejects new taps before reaching the native system boundary")
        gate.setEnabled(true) { port.enabled = true }
        suite.expect(!port.enabled, "a queued timeout or activation cannot rearm a tap after reset")
        var teardownRan = false
        gate.setEnabled(false) { teardownRan = true }
        suite.expect(teardownRan, "teardown remains permitted under the reset lock")
        gate.blockUntilRestart()
        suite.expect(port.stops == 1, "repeated reset locking is idempotent")

        let concurrent = InputTapGate<Port>(isValid: { $0.valid }, invalidate: { $0.valid = false })
        let concurrentPort = Port()
        let creating = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = DispatchGroup()
        finished.enter()
        DispatchQueue.global().async {
            _ = concurrent.create {
                creating.signal()
                _ = release.wait(timeout: .now() + 2)
                return concurrentPort
            }
            finished.leave()
        }
        suite.expect(creating.wait(timeout: .now() + 2) == .success,
                     "the concurrent creation fixture reached the native boundary")
        finished.enter()
        DispatchQueue.global().async {
            concurrent.blockUntilRestart()
            finished.leave()
        }
        release.signal()
        let settled = finished.wait(timeout: .now() + 3) == .success
        suite.expect(settled && concurrent.isBlocked && !concurrentPort.valid,
                     "a racing background tap creation cannot escape permission-reset teardown")

        let root = "Sources/Lattice"
        let paths = (try? FileManager.default.subpathsOfDirectory(atPath: root)) ?? []
        let bypasses = paths.filter { $0.hasSuffix(".swift") && !$0.hasSuffix("/InputEventTap.swift") }
            .filter {
                let code = (try? String(contentsOfFile: root + "/" + $0, encoding: .utf8)) ?? ""
                return code.contains("CGEvent.tapCreate(") || code.contains("CGEvent.tapEnable(")
            }
        suite.expect(!paths.isEmpty && bypasses.isEmpty,
                     "all production tap creation and rearming passes through the reset safety gate: \(bypasses)")
    }
}
