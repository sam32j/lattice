import AppKit

enum CapturePresentationPolicy {
    /// Above capturable elevated app dialogs, not the OS's protected higher surfaces.
    static let overlayLevel = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)

    static func overlaps(chrome: CGRect, selection: CGRect) -> Bool {
        selection.width > 0 && selection.height > 0 && chrome.intersects(selection)
    }

    static func plateOpacity(dark: Bool, overlapsSelection: Bool, reduceTransparency: Bool) -> Double {
        if reduceTransparency { return 1 }
        if overlapsSelection { return 0.97 }
        return dark ? 0.80 : 0.88
    }
}
