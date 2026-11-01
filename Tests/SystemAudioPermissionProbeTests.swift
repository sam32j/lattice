enum SystemAudioPermissionProbeTests {
    final class HAL: SystemAudioPermissionProbe {
        var failAt: Int?
        var stages: [String] = []
        var cleanupCount = 0
        var resources = 0
        var onStep: (() -> Void)?
        func step(_ name: String) -> Bool {
            stages.append(name)
            onStep?()
            guard stages.count != failAt else { return false }
            resources += 1
            return true
        }
        func createTap() -> Bool { step("tap") }
        func createDevice() -> Bool { step("device") }
        func createInput() -> Bool { step("input") }
        func startInput() -> Bool { step("start") }
        func cleanup() { cleanupCount += 1; resources = 0 }
    }

    static func run(_ suite: TestSuite) {
        let silent = HAL()
        suite.expect(SystemAudioPermissionRequest.start(using: silent)
                     && silent.stages == ["tap", "device", "input", "start"],
                     "explicit request starts audio input even without a playing process, rather than only creating a tap")
        suite.expect(silent.cleanupCount == 1 && silent.resources == 0,
                     "the temporary permission input releases every resource immediately after success")
        var cancelled = false
        let stopping = HAL()
        stopping.onStep = { cancelled = true }
        suite.expect(!SystemAudioPermissionRequest.start(using: stopping, isCancelled: { cancelled })
                     && stopping.stages == ["tap"] && stopping.cleanupCount == 1,
                     "reset during setup prevents input from starting a delayed permission request")
        for failure in 1...4 {
            let hal = HAL(); hal.failAt = failure
            suite.expect(!SystemAudioPermissionRequest.start(using: hal)
                         && hal.stages.count == failure && hal.cleanupCount == 1 && hal.resources == 0,
                         "audio request failure at stage \(failure) stops promptly and cleans partial resources")
        }
    }
}
