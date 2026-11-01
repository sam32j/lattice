/// System-audio consent is distinct from successful Core Audio device setup.
enum SystemAudioAuthorizationStatus: Equatable {
    case granted, denied, notDetermined, unavailable

    init(preflight: Int32) {
        switch preflight {
        case 0: self = .granted
        case 1: self = .denied
        case 2: self = .notDetermined
        default: self = .unavailable
        }
    }
}

enum SystemAudioAccessResult: Equatable { case granted, denied, needsSettings, unavailable }

protocol SystemAudioAuthorizationBackend {
    func authorizationStatus() -> SystemAudioAuthorizationStatus
    func requestAuthorization(completion: @escaping (SystemAudioAccessResult) -> Void)
}

enum SystemAudioAuthorizationRequest {
    static func request(using backend: SystemAudioAuthorizationBackend,
                        isCancelled: @escaping () -> Bool = { false },
                        completion: @escaping (SystemAudioAccessResult) -> Void) {
        guard !isCancelled() else { completion(.unavailable); return }
        let status = backend.authorizationStatus()
        guard !isCancelled() else { completion(.unavailable); return }
        switch status {
        case .granted: completion(.granted)
        case .denied: completion(.needsSettings)
        case .unavailable: completion(.unavailable)
        case .notDetermined:
            backend.requestAuthorization { result in
                completion(isCancelled() ? .unavailable : result)
            }
        }
    }
}
