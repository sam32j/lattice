// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import AVFoundation

/// Hides desktop icons without touching or restarting Finder by placing a
/// lightweight backdrop window immediately above Finder's desktop icon layer
/// (at `kCGDesktopIconWindowLevel + 1`) displaying the current wallpaper.
/// All normal application windows, menus, and the Dock sit far above it.
final class DesktopCurtainService {
    static let shared = DesktopCurtainService()

    private var curtainWindows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private(set) var isCurtainActive = false
    private var cachedWallpapers: [CGDirectDisplayID: NSImage] = [:]

    private init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cachedWallpapers.removeAll()
            self?.repositionCurtains()
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cachedWallpapers.removeAll()
            self?.refreshWallpapers()
        }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
    }

    func syncWithPreferences() {
        let active = UserDefaults.standard.bool(forKey: DefaultsKey.desktopCurtainActive)
        setHidden(active)
    }

    func setHidden(_ hide: Bool) {
        UserDefaults.standard.set(hide, forKey: DefaultsKey.desktopCurtainActive)
        if hide {
            showCurtains()
        } else {
            hideCurtains()
        }
    }

    func toggle() {
        setHidden(!isCurtainActive)
    }

    private func showCurtains() {
        isCurtainActive = true
        repositionCurtains()
    }

    private func hideCurtains() {
        isCurtainActive = false
        for window in curtainWindows {
            window.orderOut(nil)
        }
        curtainWindows.removeAll()
    }

    private func repositionCurtains() {
        guard isCurtainActive else { return }
        let screens = NSScreen.screens
        // Reuse the windows already up so a screen change only moves them;
        // tearing them down would flash the icons between two frames.
        while curtainWindows.count > screens.count {
            curtainWindows.removeLast().orderOut(nil)
        }
        while curtainWindows.count < screens.count {
            curtainWindows.append(makeCurtainWindow())
        }
        for (window, screen) in zip(curtainWindows, screens) {
            if let backdropView = window.contentView as? DesktopBackdropView {
                backdropView.image = resolveWallpaper(for: screen)
            }
            window.setFrame(screen.frame, display: false)
            window.orderFrontRegardless()
        }
    }

    private func makeCurtainWindow() -> NSWindow {
        let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        let window = NSWindow(contentRect: .zero,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.level = NSWindow.Level(iconLevel + 1)
        window.isOpaque = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        // Without this AppKit plays its window entrance on order-front, and
        // the wallpaper copy visibly springs into place over the real one.
        window.animationBehavior = .none
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.backgroundColor = .black
        window.contentView = DesktopBackdropView(frame: .zero)
        return window
    }

    private func refreshWallpapers() {
        guard isCurtainActive else { return }
        for (window, screen) in zip(curtainWindows, NSScreen.screens) {
            if let backdropView = window.contentView as? DesktopBackdropView,
               let image = resolveWallpaper(for: screen) {
                backdropView.image = image
            }
        }
    }

    /// Captures the live Wallpaper layer currently rendered by WindowServer for this screen.
    private func captureLiveWallpaper(for screen: NSScreen) -> NSImage? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let screenBounds = CGDisplayBounds(screenNumber ?? CGMainDisplayID())

        // The Wallpaper process draws the desktop picture itself. Window
        // Manager keeps a second copy it scales for Stage Manager and the
        // reveal-desktop gesture, so it is only a fallback.
        let candidates = windowList.filter { ($0[kCGWindowOwnerName as String] as? String) == "Wallpaper" }
            + windowList.filter { ($0[kCGWindowOwnerName as String] as? String) == "WindowManager" }
        for win in candidates {
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            let name = win[kCGWindowName as String] as? String ?? ""
            guard (owner == "WindowManager" || owner == "Wallpaper"),
                  (name == "Wallpaper" || name.isEmpty),
                  let wid = win[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? Double,
                  let y = boundsDict["Y"] as? Double,
                  let width = boundsDict["Width"] as? Double,
                  let height = boundsDict["Height"] as? Double else { continue }

            let winRect = CGRect(x: x, y: y, width: width, height: height)
            if winRect.intersects(screenBounds) {
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("lattice_curtain_\(wid)_\(screenNumber ?? 0).png")
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                p.arguments = ["-x", "-l", "\(wid)", tempURL.path]
                try? p.run()
                p.waitUntilExit()
                if p.terminationStatus == 0,
                   let img = NSImage(contentsOf: tempURL) {
                    try? FileManager.default.removeItem(at: tempURL)
                    return img
                }
            }
        }
        return nil
    }

    /// Resolves the user's actual active wallpaper across macOS versions,
    /// supporting custom images, aerial video frames, and dynamic wallpapers.
    private func resolveWallpaper(for screen: NSScreen) -> NSImage? {
        let screenID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? CGMainDisplayID()
        if let cached = cachedWallpapers[screenID] {
            return cached
        }
        if let live = captureLiveWallpaper(for: screen) {
            cachedWallpapers[screenID] = live
            return live
        }

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let storeDir = support.appendingPathComponent("com.apple.wallpaper/Store", isDirectory: true)
        let indexURLs = [storeDir.appendingPathComponent("Index.plist"), storeDir.appendingPathComponent("Index_v2.plist")]

        for indexURL in indexURLs {
            guard let data = try? Data(contentsOf: indexURL),
                  let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                continue
            }

            var containers: [[String: Any]] = []
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            if let screenNumber, let displays = root["Displays"] as? [String: Any],
               let displayEntry = displays[String(screenNumber)] as? [String: Any] {
                containers.append(displayEntry)
            }
            if let allSpaces = root["AllSpacesAndDisplays"] as? [String: Any] {
                containers.append(allSpaces)
            }
            if let sysDef = root["SystemDefault"] as? [String: Any] {
                containers.append(sysDef)
            }

            for container in containers {
                let slot = (container["Desktop"] as? [String: Any]) ?? (container["Linked"] as? [String: Any])
                guard let content = slot?["Content"] as? [String: Any],
                      let choices = content["Choices"] as? [[String: Any]] else { continue }

                for choice in choices {
                    let provider = choice["Provider"] as? String ?? ""
                    if let configData = choice["Configuration"] as? Data,
                       let config = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String: Any] {

                        if provider.contains("image"), let urlDict = config["url"] as? [String: Any],
                           let rel = urlDict["relative"] as? String, let url = URL(string: rel) {
                            if let img = NSImage(contentsOf: url) {
                                return img
                            }
                        }

                        if provider.contains("aerial"), let assetID = config["assetID"] as? String {
                            let aerialVideo = support.appendingPathComponent("com.apple.wallpaper/aerials/videos/\(assetID).mov")
                            if FileManager.default.fileExists(atPath: aerialVideo.path) {
                                let asset = AVURLAsset(url: aerialVideo)
                                let generator = AVAssetImageGenerator(asset: asset)
                                generator.appliesPreferredTrackTransform = true
                                if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                                    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                                }
                            }
                            let aerialThumb = support.appendingPathComponent("com.apple.wallpaper/aerials/thumbnails/\(assetID).png")
                            if let img = NSImage(contentsOf: aerialThumb) {
                                return img
                            }
                        }
                    }

                    if let files = choice["Files"] as? [[String: Any]] {
                        for fileEntry in files {
                            if let rel = fileEntry["relative"] as? String, let url = URL(string: rel) {
                                if let img = NSImage(contentsOf: url) {
                                    return img
                                }
                            }
                        }
                    }
                }
            }
        }

        if let fallbackURL = NSWorkspace.shared.desktopImageURL(for: screen),
           let img = NSImage(contentsOf: fallbackURL) {
            return img
        }
        return nil
    }
}

/// Shows the wallpaper as layer contents, filled the way the desktop fills
/// it, so the first frame is ready as soon as the window orders in.
private final class DesktopBackdropView: NSView {
    var image: NSImage? {
        didSet { updateContents() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        layer?.contentsGravity = .resizeAspectFill
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { true }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContents()
    }

    private func updateContents() {
        guard let layer else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.begin()
        // A layer-backed view's contents would otherwise cross-fade.
        CATransaction.setDisableActions(true)
        layer.contentsScale = scale
        layer.contents = image?.layerContents(forContentsScale: scale)
        CATransaction.commit()
    }
}
