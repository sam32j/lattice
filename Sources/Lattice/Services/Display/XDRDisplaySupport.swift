import AppKit

/// Read-only capability detection. Querying support never constructs the
/// overlay service, Metal device, timers, or windows.
enum XDRDisplaySupport {
    static let modelIdentifier: String? = {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }()

    static var supportedScreen: NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { return false }
            return CGDisplayIsBuiltin(number.uint32Value) != 0
                && ExtraBrightnessSupport.isSupportedPanel(
                    model: modelIdentifier, localizedName: screen.localizedName,
                    potentialEDR: Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue))
        }
    }
}
