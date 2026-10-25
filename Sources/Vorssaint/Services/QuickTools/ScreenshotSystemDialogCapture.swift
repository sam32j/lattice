import AppKit
import CoreGraphics

enum ScreenshotSystemDialogCapture {
    private static func metadata(_ id: CGWindowID) -> (owner: String, frame: CGRect)? {
        guard let row = (CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]])?.first,
              let owner = row[kCGWindowOwnerName as String] as? String,
              ["UserNotificationCenter", "UserNotificationCenterAgent", "CoreServicesUIAgent"].contains(owner),
              let raw = row[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        return (owner, CGRect(x: raw["X"] ?? 0, y: raw["Y"] ?? 0,
            width: raw["Width"] ?? 0, height: raw["Height"] ?? 0))
    }

    static func refine(_ windows: [(id: CGWindowID, bounds: CGRect)]) async -> [(id: CGWindowID, bounds: CGRect)] {
        var result = windows
        for index in windows.indices {
            guard !Task.isCancelled else { return result }
            let window = windows[index]
            guard metadata(window.id) != nil,
                  let image = await WindowPreviewProvider.captureViaWindowServer(window.id),
                  let content = ScreenshotDialogGeometry.content(in: image, windowFrame: window.bounds) else { continue }
            result[index].bounds = content.frame
        }
        return result
    }

    static func normalize(_ capture: (image: CGImage, scale: CGFloat)?, windowID: CGWindowID)
        -> (image: CGImage, scale: CGFloat)? {
        guard let capture else { return nil }
        guard let source = metadata(windowID),
              let content = ScreenshotDialogGeometry.content(in: capture.image, windowFrame: source.frame) else { return capture }
        return (content.image, CGFloat(content.image.width) / content.frame.width)
    }
}
