enum SystemAudioAuthorizationTests {
    final class TCC: SystemAudioAuthorizationBackend {
        var status = SystemAudioAuthorizationStatus.notDetermined
        var requests = 0
        var reply: ((SystemAudioAccessResult) -> Void)?
        func authorizationStatus() -> SystemAudioAuthorizationStatus { status }
        func requestAuthorization(completion: @escaping (SystemAudioAccessResult) -> Void) {
            requests += 1; reply = completion
        }
    }
    static func run(_ suite: TestSuite) {
        let tcc = TCC()
        var result: SystemAudioAccessResult?
        tcc.status = .denied
        SystemAudioAuthorizationRequest.request(using: tcc) { result = $0 }
        suite.expect(result == .needsSettings && tcc.requests == 0,
                     "denied system audio stays denied and routes retry to Settings, never device-start success")
        tcc.status = .unavailable; result = nil
        SystemAudioAuthorizationRequest.request(using: tcc) { result = $0 }
        suite.expect(result == .unavailable && tcc.requests == 0,
                     "missing authorization API never implies granted access")
        tcc.status = .notDetermined; result = nil
        SystemAudioAuthorizationRequest.request(using: tcc) { result = $0 }
        suite.expect(result == nil && tcc.requests == 1, "a first request waits for the actual native consent decision")
        tcc.reply?(.denied)
        suite.expect(result == .denied, "a native Deny response never becomes an enabled visualizer")
        result = nil
        SystemAudioAuthorizationRequest.request(using: tcc) { result = $0 }
        tcc.reply?(.granted)
        suite.expect(result == .granted, "only a native grant or authorized preflight permits activation")
        tcc.status = .granted; result = nil
        SystemAudioAuthorizationRequest.request(using: tcc) { result = $0 }
        suite.expect(result == .granted && tcc.requests == 2, "an existing genuine grant needs no repeat native prompt")
        var cancelled = true; result = nil
        SystemAudioAuthorizationRequest.request(using: tcc, isCancelled: { cancelled }) { result = $0 }
        suite.expect(result != .granted, "a cancelled request cannot accept an existing grant")
        cancelled = false; tcc.status = .notDetermined; result = nil
        SystemAudioAuthorizationRequest.request(using: tcc, isCancelled: { cancelled }) { result = $0 }
        cancelled = true; tcc.reply?(.granted)
        suite.expect(result != .granted, "a cancelled in-flight consent reply cannot enable a feature")
        suite.expect(SystemAudioAuthorizationStatus(preflight: 0) == .granted
                     && SystemAudioAuthorizationStatus(preflight: 1) == .denied
                     && SystemAudioAuthorizationStatus(preflight: 2) == .notDetermined
                     && SystemAudioAuthorizationStatus(preflight: -1) == .unavailable
                     && SystemAudioAuthorizationStatus(preflight: 99) == .unavailable,
                     "unexpected authorization return values fail closed rather than becoming grants or prompts")
    }
}
