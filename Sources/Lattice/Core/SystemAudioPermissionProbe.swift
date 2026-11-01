/// The HAL boundary used only by an explicit, short-lived permission request.
protocol SystemAudioPermissionProbe: AnyObject {
    func createTap() -> Bool
    func createDevice() -> Bool
    func createInput() -> Bool
    func startInput() -> Bool
    func cleanup()
}

enum SystemAudioPermissionRequest {
    static func start(using probe: SystemAudioPermissionProbe, isCancelled: () -> Bool = { false }) -> Bool {
        defer { probe.cleanup() }
        guard !isCancelled(), probe.createTap(), !isCancelled(), probe.createDevice(),
              !isCancelled(), probe.createInput(), !isCancelled(), probe.startInput() else { return false }
        return !isCancelled()
    }
}
