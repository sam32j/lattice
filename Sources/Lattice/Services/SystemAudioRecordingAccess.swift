import Darwin
import Foundation

/// TCC is queried off the main thread. Device startup is not authorization.
enum SystemAudioRecordingAccess {
    private static var pending: FeatureWorkCancellation?

    @discardableResult
    static func request(completion: @escaping (SystemAudioAccessResult) -> Void) -> FeatureWorkCancellation {
        cancelPending()
        let work = FeatureWorkCancellation()
        pending = work
        DispatchQueue.global(qos: .userInitiated).async {
            SystemAudioAuthorizationRequest.request(using: TCCSystemAudioBackend(),
                isCancelled: { work.isCancelled }) { result in
                DispatchQueue.main.async {
                    if pending === work { pending = nil }
                    completion(work.isCancelled ? .unavailable : result)
                }
            }
        }
        return work
    }

    @discardableResult
    static func check(completion: @escaping (SystemAudioAuthorizationStatus) -> Void) -> FeatureWorkCancellation {
        let work = FeatureWorkCancellation()
        DispatchQueue.global(qos: .userInitiated).async {
            let status = work.isCancelled ? .unavailable : TCCSystemAudioBackend().authorizationStatus()
            DispatchQueue.main.async { completion(work.isCancelled ? .unavailable : status) }
        }
        return work
    }

    static func cancelPending() {
        pending?.cancel()
        pending = nil
    }
}

/// Matches the app's existing dynamic TCC preflight integration. Missing SPI fails closed.
private struct TCCSystemAudioBackend: SystemAudioAuthorizationBackend {
    private typealias Preflight = @convention(c) (CFString, CFDictionary?) -> Int32
    private typealias Reply = @convention(block) (Bool) -> Void
    private typealias Request = @convention(c) (CFString, CFDictionary?, Reply) -> Void
    // Retain the framework for the lifetime of asynchronous callbacks.
    private static let handle = dlopen("/System/Library/PrivateFrameworks/TCC.framework/TCC", RTLD_LAZY)
    private static let service = "kTCCServiceAudioCapture" as CFString

    func authorizationStatus() -> SystemAudioAuthorizationStatus {
        guard #available(macOS 14.4, *), let handle = Self.handle,
              let symbol = dlsym(handle, "TCCAccessPreflight") else { return .unavailable }
        return SystemAudioAuthorizationStatus(preflight: unsafeBitCast(symbol, to: Preflight.self)(Self.service, nil))
    }

    func requestAuthorization(completion: @escaping (SystemAudioAccessResult) -> Void) {
        guard #available(macOS 14.4, *), let handle = Self.handle,
              let symbol = dlsym(handle, "TCCAccessRequest") else { completion(.unavailable); return }
        let reply: Reply = { granted in completion(granted ? .granted : .denied) }
        unsafeBitCast(symbol, to: Request.self)(Self.service, nil, reply)
    }
}
