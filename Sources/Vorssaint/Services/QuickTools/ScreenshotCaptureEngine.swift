// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import ScreenCaptureKit

/// Raw pixel acquisition for the screenshot tool. Displays go through
/// ScreenCaptureKit; a clicked window prefers the window server so the result
/// is the window's own crisp buffer (rounded corners, no neighbors bleeding
/// in), with ScreenCaptureKit as the fallback. The windows the screenshot
/// workflow puts on screen are always excluded so captures never contain the
/// tool taking them; other app windows stay eligible unless the caller excludes them.
enum ScreenshotCaptureEngine {

    /// Full-resolution capture of one display.
    static func captureDisplay(_ displayID: CGDirectDisplayID,
                               includePointer: Bool,
                               excludingAppWindows: Bool = false,
                               protectedWindowIDs: Set<CGWindowID>) async -> CGImage? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        else { return nil }
        guard let display = content.displays.first(where: { $0.displayID == displayID })
        else { return nil }

        let ownWindows = await excludedOwnWindows(in: content,
                                            excludingAppWindows: excludingAppWindows,
                                            protectedWindowIDs: protectedWindowIDs)
        return await captureDisplay(display,
                                    scale: screenScale(for: displayID),
                                    excluding: ownWindows,
                                    includePointer: includePointer)
    }

    /// Immutable capture configuration owned by one scrolling session. Resolving
    /// shareable windows for every frame adds latency and loses page overlap.
    final class RegionCapture: @unchecked Sendable {
        private let filter: SCContentFilter
        private let configuration: SCStreamConfiguration

        init(filter: SCContentFilter, configuration: SCStreamConfiguration) {
            self.filter = filter
            self.configuration = configuration
        }

        func image() async -> CGImage? {
            try? await SCScreenshotManager.captureImage(contentFilter: filter,
                                                       configuration: configuration)
        }
    }

    /// `keepsIslandOut` leaves the island out even where it normally shows in
    /// captures, for a reading that must not see the island itself change.
    static func prepareDisplayRegion(displayID: CGDirectDisplayID,
                                     pixelRect: CGRect,
                                     includePointer: Bool,
                                     excludingAppWindows: Bool = false,
                                     protectedWindowIDs: Set<CGWindowID>,
                                     keepsIslandOut: Bool = false) async -> RegionCapture? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true),
            let display = content.displays.first(where: { $0.displayID == displayID })
        else { return nil }
        let scale = screenScale(for: displayID)
        let displayPixels = CGRect(x: 0, y: 0,
                                   width: CGFloat(display.width) * scale,
                                   height: CGFloat(display.height) * scale)
        let clamped = ScreenshotSupport.clamp(pixelRect, to: displayPixels).integral
        guard !clamped.isEmpty else { return nil }
        let ownWindows = await excludedOwnWindows(in: content,
                                            excludingAppWindows: excludingAppWindows,
                                            protectedWindowIDs: protectedWindowIDs,
                                            keepsIslandOut: keepsIslandOut)
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(x: clamped.minX / scale,
                                          y: clamped.minY / scale,
                                          width: clamped.width / scale,
                                          height: clamped.height / scale)
        configuration.width = max(1, Int(clamped.width))
        configuration.height = max(1, Int(clamped.height))
        configuration.showsCursor = includePointer
        configuration.colorSpaceName = CGColorSpace.sRGB
        return RegionCapture(filter: filter, configuration: configuration)
    }

    /// Captures every given screen, keyed by display id. Screens that fail
    /// are simply absent; the caller decides how to degrade.
    static func captureAllDisplays(includePointer: Bool,
                                   excludingAppWindows: Bool = false,
                                   protectedWindowIDs: Set<CGWindowID>) async -> [CGDirectDisplayID: CGImage] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        else { return [:] }
        let ownWindows = await excludedOwnWindows(in: content,
                                            excludingAppWindows: excludingAppWindows,
                                            protectedWindowIDs: protectedWindowIDs)
        let screens = NSScreen.screens
        return await withTaskGroup(of: (CGDirectDisplayID, CGImage?).self) { group in
            for screen in screens {
                let id = screen.displayID
                guard id != 0,
                      let display = content.displays.first(where: { $0.displayID == id })
                else { continue }
                let scale = screen.backingScaleFactor
                group.addTask {
                    let image = await captureDisplay(display,
                                                     scale: scale,
                                                     excluding: ownWindows,
                                                     includePointer: includePointer)
                    return (id, image)
                }
            }
            var result: [CGDirectDisplayID: CGImage] = [:]
            for await (id, image) in group {
                if let image {
                    result[id] = image
                }
            }
            return result
        }
    }

    /// The app's own windows a display capture must leave out, resolved
    /// against the same shareable-content snapshot the capture will use.
    @MainActor
    private static func excludedOwnWindows(in content: SCShareableContent,
                                           excludingAppWindows: Bool = false,
                                           protectedWindowIDs: Set<CGWindowID>,
                                           keepsIslandOut: Bool = false) -> [SCWindow] {
        let ownWindowIDs = Set(content.windows.compactMap { window in
            window.owningApplication?.processID == getpid() ? window.windowID : nil
        })
        // The island has its own preference for captures, independent of
        // excluding the app's ordinary windows. Capture previews stay out,
        // while normal island activities follow the island visibility setting.
        let islandIDs = !keepsIslandOut && NotchSupport.isEnabled()
            ? NotchService.shared.captureVisibleWindowIDs : []
        let excludedIDs = ScreenshotCapturePolicy.excludedWindowIDs(
            excludingAppWindows: excludingAppWindows,
            ownWindowIDs: ownWindowIDs,
            protectedWindowIDs: protectedWindowIDs,
            islandWindowIDs: islandIDs)
        return content.windows.filter {
            excludedIDs.contains($0.windowID) || isSystemOverlayWindow($0)
        }
    }

    /// System overlay windows (such as Mission Control's blue hover ring) that should
    /// never be stamped into screen or region captures.
    private static func isSystemOverlayWindow(_ window: SCWindow) -> Bool {
        if window.title == "Window Highlight Overlay" {
            return true
        }
        if window.owningApplication?.bundleIdentifier == "com.apple.WindowManager",
           window.title == "Window Highlight Overlay" || window.title == "Gesture Blocking Overlay" {
            return true
        }
        return false
    }

    private static func isOverlayWindow(_ windowID: CGWindowID) -> Bool {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let dict = info.first else { return false }
        let owner = dict[kCGWindowOwnerName as String] as? String ?? ""
        let name = dict[kCGWindowName as String] as? String ?? ""
        return owner == "WindowManager" || name == "Window Highlight Overlay"
    }

    private static func captureDisplay(_ display: SCDisplay,
                                       scale: CGFloat,
                                       excluding ownWindows: [SCWindow],
                                       includePointer: Bool) async -> CGImage? {
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((CGFloat(display.width) * scale).rounded()))
        configuration.height = max(1, Int((CGFloat(display.height) * scale).rounded()))
        configuration.showsCursor = includePointer
        configuration.colorSpaceName = CGColorSpace.sRGB
        return try? await SCScreenshotManager.captureImage(contentFilter: filter,
                                                           configuration: configuration)
    }

    /// The window's own buffer via the window server (same capture the
    /// switcher thumbnails use), full resolution, falling back to
    /// ScreenCaptureKit when the private route is unavailable or when it
    /// returns only the visible slice of a window that runs off the screen.
    /// The scale comes back with the image: a composite with what the app
    /// stacked on the window is drawn at the scale its layers were captured
    /// at, which on mixed displays can differ from the one asked for.
    static func captureWindow(_ windowID: CGWindowID,
                              scale: CGFloat,
                              includeAttachedWindows: Bool = true) async -> (image: CGImage, scale: CGFloat)? {
        if isOverlayWindow(windowID) {
            return nil
        }
        // A sheet or dialog the app stacked on the window is a window of its
        // own, and neither single-window route draws it (issue #1098). The
        // window list answers this without waiting on shareable content, so
        // the ordinary capture keeps the faster route.
        let onScreen = onScreenWindows()
        if includeAttachedWindows, let target = onScreen.first(where: { $0.id == windowID }),
           let geometricPlan = ScreenshotCapturePolicy.attachedCapturePlan(
               target: target, frontToBack: onScreen) {
            var plan: ScreenshotCapturePolicy.AttachedCapturePlan? = geometricPlan
            if Permissions.shared.accessibility {
                let confirmedIDs = accessibilityAttachedWindowIDs(
                    targetWindowID: target.id,
                    ownerPID: target.ownerPID,
                    candidateWindowIDs: Array(geometricPlan.windowIDs.dropFirst()))
                plan = ScreenshotCapturePolicy.confirmedAttachment(
                    geometricPlan, confirmedIDs: confirmedIDs)
            }
            if let plan,
               let composited = await captureAttached(plan) {
                return composited
            }
            // A window spanning two displays has no single display image to
            // crop from; draw each window's own buffer at its place instead
            // of dropping the dialog on it.
            if let plan,
               let composited = await composeAttached(plan, frames: Dictionary(
                   onScreen.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })) {
                return composited
            }
        }
        let capturedImage = await WindowPreviewProvider.captureViaWindowServer(windowID)
        guard !Task.isCancelled else { return nil }
        if let image = capturedImage, !ScreenshotSupport.isImageBlank(image) {
            let bounds = windowBounds(windowID)
            if bounds.map({ SwitcherSupport.captureCoversWindow(imageWidth: image.width,
                                                                imageHeight: image.height,
                                                                windowSize: $0.size) }) ?? true {
                return (image, scale)
            }
        }
        let capture = await captureIndependentWindow(windowID, scale: scale)
        // WindowServer quality decides whether to retry with ScreenCaptureKit.
        // The chooser makes the final composed-display fallback decision once,
        // including for an intentionally uniform but otherwise valid window.
        if let capture {
            return (capture, scale)
        }
        return capturedImage.map { ($0, scale) }
    }

    /// The window drawn on its own by ScreenCaptureKit, whole wherever it
    /// sits. Watch reads a window through this as well, in its capture turn.
    static func captureIndependentWindow(_ windowID: CGWindowID, scale: CGFloat) async -> CGImage? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true),
            let window = content.windows.first(where: { $0.windowID == windowID })
        else { return nil }
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((window.frame.width * scale).rounded()))
        configuration.height = max(1, Int((window.frame.height * scale).rounded()))
        // The resolution choice only exists for an independent window, and
        // its automatic setting may render below the window's own scale and
        // stretch the result to the size asked for. The recorder already asks
        // for the best one; this is the screenshot tool's only window stream.
        configuration.captureResolution = .best
        configuration.showsCursor = false
        configuration.colorSpaceName = CGColorSpace.sRGB
        // A desktop-independent window may extend beyond its source display.
        // Requested dimensions alone do not restore pixels clipped there.
        configuration.ignoreGlobalClipSingleWindow = true
        let filter = SCContentFilter(desktopIndependentWindow: window)
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    /// Resolve each selected layer before compositing. Empty space between
    /// windows is intentional transparency, never a failed display capture.
    static func captureMultipleWindows(_ windowIDs: [CGWindowID],
                                       scale: CGFloat,
                                       frames: [CGWindowID: CGRect],
                                       resolveCapture: (CGWindowID, (image: CGImage, scale: CGFloat)?)
                                           -> (image: CGImage, scale: CGFloat)?)
        async -> (image: CGImage, scale: CGFloat)? {
        guard !Task.isCancelled, !windowIDs.isEmpty, scale.isFinite, scale > 0 else { return nil }

        let onScreen = onScreenWindows()
        // Capture each window independently: multi-window filters can pack pixels
        // at the output origin instead of preserving desktop coordinates.
        let selectedFrames = windowIDs.compactMap { frames[$0] }
        guard selectedFrames.count == windowIDs.count,
              selectedFrames.allSatisfy({ !$0.isEmpty && !$0.isInfinite }) else { return nil }
        var unionBounds = selectedFrames[0]
        for frame in selectedFrames.dropFirst() {
            unionBounds = unionBounds.union(frame)
        }

        let sortedIDs = onScreen.filter { windowIDs.contains($0.id) }.reversed().map(\.id)
        let orderedIDs = sortedIDs + windowIDs.filter { !sortedIDs.contains($0) }

        var layers: [(image: CGImage, frame: CGRect)] = []
        for id in orderedIDs {
            guard !Task.isCancelled, let frame = frames[id] else { return nil }
            let independent = await captureWindow(id, scale: scale, includeAttachedWindows: false)
            guard !Task.isCancelled else { return nil }
            let candidate = independent.flatMap { capture in
                SwitcherSupport.captureCoversWindow(imageWidth: capture.image.width,
                    imageHeight: capture.image.height, windowSize: frame.size) ? capture : nil
            }
            let resolved = resolveCapture(id, candidate)
            guard !Task.isCancelled, let capture = resolved,
                  SwitcherSupport.captureCoversWindow(imageWidth: capture.image.width,
                                                      imageHeight: capture.image.height,
                                                      windowSize: frame.size)
            else { return nil }
            layers.append((capture.image, frame))
        }

        guard !Task.isCancelled else { return nil }
        let width = max(1, Int((unionBounds.width * scale).rounded()))
        let height = max(1, Int((unionBounds.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        for layer in layers {
            context.draw(layer.image, in: ScreenshotCapturePolicy.compositeRect(
                for: layer.frame, in: unionBounds, scale: scale))
        }
        return context.makeImage().map { ($0, scale) }
    }

    /// On-screen windows front to back, as the attached-window decision needs
    /// them. Ordinary layer-zero windows only, so a menu or the Dock cannot
    /// read as something stacked on the clicked window.
    private static func onScreenWindows() -> [ScreenshotCapturePolicy.CaptureWindow] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return captureWindows(in: info)
    }

    private static func captureWindows(in info: [[String: Any]]) -> [ScreenshotCapturePolicy.CaptureWindow] {
        info.compactMap { entry in
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat]
            else { return nil }
            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha <= 0.01 { return nil }
            return ScreenshotCapturePolicy.CaptureWindow(
                id: id,
                ownerPID: pid,
                frame: CGRect(x: boundsDict["X"] ?? 0,
                              y: boundsDict["Y"] ?? 0,
                              width: boundsDict["Width"] ?? 0,
                              height: boundsDict["Height"] ?? 0),
                isUntitled: (entry[kCGWindowName as String] as? String)?.isEmpty ?? true)
        }
    }

    /// The geometric candidates Accessibility does not positively identify as
    /// standard windows. `nil` means the app did not provide a window map that
    /// names the target.
    private static func accessibilityAttachedWindowIDs(
        targetWindowID: CGWindowID,
        ownerPID: pid_t,
        candidateWindowIDs: [CGWindowID]) -> Set<CGWindowID>? {
        guard AXIsProcessTrusted() else { return nil }
        let application = AXUIElementCreateApplication(ownerPID)
        guard let windows = accessibilityElements(application, kAXWindowsAttribute as CFString)
        else { return nil }

        var elementsByID: [CGWindowID: AXUIElement] = [:]
        for window in windows {
            if let id = AXWindowResolver.windowID(for: window) {
                elementsByID[id] = window
            }
        }
        guard !elementsByID.isEmpty,
              elementsByID[targetWindowID] != nil
        else { return nil }

        var confirmed: Set<CGWindowID> = []
        for candidateID in candidateWindowIDs {
            guard let element = elementsByID[candidateID] else {
                // AX had no answer for this one — only a window AX positively identifies as standard is filtered out.
                confirmed.insert(candidateID)
                continue
            }
            // The standard set matches what the auto-quit and enumeration paths already read.
            if let subrole = accessibilityString(element, kAXSubroleAttribute as CFString),
               subrole == (kAXStandardWindowSubrole as String) || subrole == "AXFullScreenWindow" {
                continue
            }
            confirmed.insert(candidateID)
        }
        return confirmed
    }

    private static func accessibilityElements(_ element: AXUIElement,
                                              _ attribute: CFString) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let elements = value as? [AXUIElement]
        else { return nil }
        return elements
    }

    private static func accessibilityString(_ element: AXUIElement,
                                            _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success
        else { return nil }
        return value as? String
    }

    /// Draws the clicked window together with what the app stacked on it.
    /// ScreenCaptureKit is the only route that takes more than one window. It
    /// captures their composited display, then crops it to the area they cover.
    /// `nil` leaves the single-window routes to answer. The scale is that
    /// display's, which the crop keeps.
    private static func captureAttached(
        _ plan: ScreenshotCapturePolicy.AttachedCapturePlan) async -> (image: CGImage, scale: CGFloat)? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        else { return nil }
        let windows = plan.windowIDs.compactMap { id in
            content.windows.first { $0.windowID == id }
        }
        let hits = content.displays.filter { $0.frame.intersects(plan.bounds) }
        // A window straddling two displays has no single display to crop from,
        // while one hanging off a lone display's edge still does: the crop
        // clamps the part that is on screen.
        guard windows.count == plan.windowIDs.count,
              hits.count == 1,
              let display = hits.first,
              let screen = NSScreen.screens.first(where: { $0.displayID == display.displayID }),
              let mainScreen = NSScreen.screens.first
        else { return nil }
        let filter = SCContentFilter(display: display, including: windows)
        let configuration = SCStreamConfiguration()
        let pixelScale = CGFloat(filter.pointPixelScale)
        configuration.width = max(1, Int((CGFloat(display.width) * pixelScale).rounded()))
        configuration.height = max(1, Int((CGFloat(display.height) * pixelScale).rounded()))
        configuration.showsCursor = false
        configuration.colorSpaceName = CGColorSpace.sRGB
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                      configuration: configuration)
        else { return nil }
        let cocoaBounds = ScreenshotSupport.cocoaRect(fromWindowServer: plan.bounds,
                                                      mainScreenHeight: mainScreen.frame.height)
        let viewBounds = ScreenshotSupport.flippedViewRect(fromCocoa: cocoaBounds,
                                                           screenFrame: screen.frame)
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let pixelBounds = ScreenshotSupport.imagePixelRect(
            fromView: viewBounds,
            viewSize: screen.frame.size,
            imageSize: imageBounds.size)
        let cropBounds = ScreenshotSupport.clamp(pixelBounds, to: imageBounds)
        guard !cropBounds.isEmpty else { return nil }
        let packedBounds = ScreenshotSupport.clamp(
            CGRect(origin: .zero, size: cropBounds.size), to: imageBounds)
        guard packedBounds != cropBounds, let alpha = alphaCoverage(of: image) else {
            return image.cropping(to: cropBounds).map { ($0, pixelScale) }
        }
        return image.cropping(to: ScreenshotSupport.attachedCaptureCrop(
            placed: cropBounds, packed: packedBounds, coverage: alpha)).map { ($0, pixelScale) }
    }

    /// The image's alpha, one byte per pixel with the top row first, which is
    /// all it takes to tell where the included windows were drawn.
    private static func alphaCoverage(of image: CGImage) -> ScreenshotSupport.AlphaCoverage? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drawn = alpha.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? ScreenshotSupport.AlphaCoverage(alpha: alpha, width: width, height: height) : nil
    }

    /// The clicked window and what the app stacked on it, each from its own
    /// buffer, layered back to front on a canvas the size of the clicked
    /// window. Every layer has to cover its frame whole at one scale: a
    /// window-server buffer cut at a display edge or seam (a window spanning
    /// two displays is drawn on only one of them while displays have
    /// separate Spaces) is recaptured through its own ScreenCaptureKit
    /// filter, and `nil` leaves the single-window capture to answer when that
    /// is not whole either. The scale is the one the layers were captured
    /// at, not necessarily the clicked display's.
    private static func composeAttached(_ plan: ScreenshotCapturePolicy.AttachedCapturePlan,
                                        frames: [CGWindowID: CGRect]) async -> (image: CGImage, scale: CGFloat)? {
        let candidates = Array(Set(NSScreen.screens.map(\.backingScaleFactor)))
        guard let targetID = plan.windowIDs.first, let targetFrame = frames[targetID],
              !candidates.isEmpty else { return nil }
        var content: SCShareableContent?
        func independentCapture(_ id: CGWindowID, frame: CGRect, scale: CGFloat) async -> CGImage? {
            if content == nil {
                content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            }
            guard let window = content?.windows.first(where: { $0.windowID == id }) else { return nil }
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int((frame.width * scale).rounded()))
            configuration.height = max(1, Int((frame.height * scale).rounded()))
            configuration.captureResolution = .best
            configuration.showsCursor = false
            configuration.colorSpaceName = CGColorSpace.sRGB
            // A desktop-independent window may extend beyond its source display.
            // Requested dimensions alone do not restore pixels clipped there.
            configuration.ignoreGlobalClipSingleWindow = true
            return try? await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
        }

        // The clicked window sets the scale every other layer must match.
        var targetImage = await WindowPreviewProvider.captureViaWindowServer(targetID)
        guard let targetCapture = ScreenshotCapturePolicy.compositeTargetCapture(
            buffer: targetImage.map { ($0.width, $0.height) }, frame: targetFrame, candidates: candidates)
        else { return nil }
        let scale = targetCapture.scale
        if case .recapture = targetCapture {
            targetImage = await independentCapture(targetID, frame: targetFrame, scale: scale)
        }
        guard let targetImage,
              ScreenshotCapturePolicy.layerCoversFrame(imageWidth: targetImage.width,
                                                       imageHeight: targetImage.height,
                                                       frame: targetFrame, scale: scale)
        else { return nil }

        var layers: [(image: CGImage, frame: CGRect)] = [(targetImage, targetFrame)]
        for id in plan.windowIDs.dropFirst() {
            guard let frame = frames[id] else { return nil }
            var image = await WindowPreviewProvider.captureViaWindowServer(id)
            if image.map({ !ScreenshotCapturePolicy.layerCoversFrame(imageWidth: $0.width, imageHeight: $0.height,
                                                                     frame: frame, scale: scale) }) ?? true {
                image = await independentCapture(id, frame: frame, scale: scale)
            }
            guard let image,
                  ScreenshotCapturePolicy.layerCoversFrame(imageWidth: image.width, imageHeight: image.height,
                                                           frame: frame, scale: scale)
            else { return nil }
            layers.append((image, frame))
        }
        let width = max(1, Int((plan.bounds.width * scale).rounded()))
        let height = max(1, Int((plan.bounds.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)
                                          ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        for layer in layers {
            context.draw(layer.image, in: ScreenshotCapturePolicy.compositeRect(
                for: layer.frame, in: plan.bounds, scale: scale))
        }
        return context.makeImage().map { ($0, scale) }
    }

    /// The window's size as the window server knows it, used to tell a whole
    /// window capture from one clipped to the part inside a display.
    private static func windowBounds(_ windowID: CGWindowID) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let dict = info.first?[kCGWindowBounds as String] as? [String: CGFloat]
        else { return nil }
        let bounds = CGRect(x: dict["X"] ?? 0, y: dict["Y"] ?? 0,
                            width: dict["Width"] ?? 0, height: dict["Height"] ?? 0)
        return bounds.width > 1 && bounds.height > 1 ? bounds : nil
    }

    /// On-screen windows a click can capture, front to back, in the window
    /// server's global top-left coordinates. Ordinary layer-zero windows from
    /// this process remain eligible unless excluded, except for protected capture UI.
    static func pickableWindows(excludingAppWindows: Bool = false,
                                protectedWindowIDs: Set<CGWindowID>)
        -> [(id: CGWindowID, bounds: CGRect)] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        let ownPID = Int32(ProcessInfo.processInfo.processIdentifier)
        let decorations = ScreenshotCapturePolicy.decorationWindowIDs(frontToBack: captureWindows(in: info))
        return info.compactMap { entry in
            guard let layer = entry[kCGWindowLayer as String] as? Int,
                  ScreenshotCapturePolicy.isPickableWindowLayer(layer,
                      ownerName: entry[kCGWindowOwnerName as String] as? String ?? ""),
                  let pid = entry[kCGWindowOwnerPID as String] as? Int32,
                  let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat]
            else { return nil }
            guard !decorations.contains(id),
                  ScreenshotCapturePolicy.canPickWindow(
                id,
                isOwnWindow: pid == ownPID,
                excludingAppWindows: excludingAppWindows,
                protectedWindowIDs: protectedWindowIDs)
            else { return nil }
            let bounds = CGRect(x: boundsDict["X"] ?? 0,
                                y: boundsDict["Y"] ?? 0,
                                width: boundsDict["Width"] ?? 0,
                                height: boundsDict["Height"] ?? 0)
            guard bounds.width >= 40, bounds.height >= 40 else { return nil }
            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha <= 0.01 { return nil }
            return (id: id, bounds: bounds)
        }
    }

    private static func screenScale(for displayID: CGDirectDisplayID) -> CGFloat {
        NSScreen.screens.first { $0.displayID == displayID }?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
    }
}

extension NSScreen {
    /// The CoreGraphics display id behind this screen; 0 when missing, which
    /// callers treat as not capturable.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
