#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI
import Carbon.HIToolbox

/// Exercises the production views and island host in an isolated bundle without
/// invoking tool actions, requesting permissions, or changing user preferences.
enum HubPresentationProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier,
              identity.hasPrefix("io.github.sam32j.lattice.tests."),
              let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        let defaults = UserDefaults.standard
        defaults.register(defaults: Defaults.registeredDefaults)
        defaults.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        for feature in AppFeature.allCases {
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: false)
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        for item in LatticeHubItem.allCases {
            SettingsRefactorProbe.setPreviewAvailability(item.feature, enabled: true)
            for key in item.feature.enabledKeys { defaults.set(true, forKey: key) }
        }
        for feature in [AppFeature.micMute, .keepAwake, .brightness, .commandBar] {
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: true)
        }
        SettingsRefactorProbe.setPreviewAvailability(AppFeature.quickLauncher, enabled: true)
        defaults.set("", forKey: DefaultsKey.hubControlsHidden)
        var failures = [String]()
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            if !CommandLine.arguments.contains("--hud-only") { try verifyIsland(output: output) }
            if !CommandLine.arguments.contains("--island-only") { try verifyHUD(output: output, failures: &failures) }
        } catch { failures.append(String(describing: error)) }
        defaults.removePersistentDomain(forName: identity)
        for failure in failures { print("HUB_PRESENTATION_FAILED \(failure)") }
        if failures.isEmpty { print("HUB_PRESENTATION_OK") }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func verifyIsland(output: URL) throws {
        let launcher = LatticeHubService.shared
        launcher.prepareForPresentation()
        for width in [CGFloat(300), 520] {
            let size = CGSize(width: width, height: 112)
            let host = NSHostingView(rootView: LatticeHubView(notchSize: size))
            host.sizingOptions = []
            let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            defer { window.orderOut(nil); window.contentView = nil; window.close() }
            for editing in [false, true, false] {
                print("HUB_ISLAND width=\(width) editing=\(editing)"); fflush(stdout)
                launcher.isEditing = editing
                settle(host)
                try capture(host, name: "island-\(Int(width))-\(editing)", output: output)
            }
        }
        let defaults = UserDefaults.standard
        SettingsRefactorProbe.setPreviewAvailability(AppFeature.notch, enabled: true)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(NotchModule.allCases.filter { $0 != .hub }.map(\.rawValue).joined(separator: ","),
                     forKey: DefaultsKey.notchHiddenModules)
        let island = NotchService.shared
        defer {
            island.stop()
            defaults.set(false, forKey: DefaultsKey.notchEnabled)
        }
        for iteration in 0..<3 {
            print("HUB_ISLAND_OPEN iteration=\(iteration)"); fflush(stdout)
            island.open(.hub)
            guard island.expanded, island.selected == .hub,
                  let view = island.presentationWindow?.contentView else { throw CocoaError(.coderInvalidValue) }
            settle(view)
            for editing in [true, false] {
                withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = editing }
                settle(view)
                launcher.setHidden(.scratchpad, editing)
                launcher.setControlHidden(.cleaningMode, editing)
                settle(view)
            }
            try capture(view, name: "island-host-\(iteration)", output: output)
            island.collapse()
            settle(view)
        }
    }

    private static func verifyHUD(output: URL, failures: inout [String]) throws {
        let launcher = LatticeHubService.shared
        launcher.prepareForPresentation()
        let panel = launcher.ensurePanel()
        launcher.position(panel)
        let openingFrame = panel.frame
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        guard let view = panel.contentView else { throw CocoaError(.coderInvalidValue) }
        defer { panel.orderOut(nil) }
        settle(view)
        if abs(panel.frame.height - openingFrame.height) > 1 {
            failures.append("HUD changes height after opening: \(openingFrame.height) to \(panel.frame.height)")
        }
        try capture(view, name: "hud-normal", output: output)
        let original = panel.frame
        let originalHeader = try headerOffset(in: view)
        let originalFooter = try footerOffset(in: view)
        guard let handle = descendant("hub-drag-handle", in: view) else { throw CocoaError(.coderInvalidValue) }
        let handleTop = dragHandleTop(handle, in: panel)
        for (iteration, editing) in [true, false, true, false].enumerated() {
            if iteration == 3 {
                launcher.editingOptionsItem = .clipboard
                settle(view)
            }
            let top = panel.frame.maxY
            print("HUB_HUD editing=\(editing) initial=\(panel.frame)"); fflush(stdout)
            withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = editing }
            var previousHeight = panel.frame.height
            var maxTopDrift: CGFloat = 0
            var maxFooterDrift: CGFloat = 0
            var maxHeaderDrift: CGFloat = 0
            var intermediateHeights = Set<Int>()
            let deadline = Date().addingTimeInterval(0.45)
            while Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 120))
                view.layoutSubtreeIfNeeded()
                maxTopDrift = max(maxTopDrift, abs(panel.frame.maxY - top))
                let currentHandleTop = dragHandleTop(handle, in: panel)
                maxHeaderDrift = max(maxHeaderDrift, abs(currentHandleTop - handleTop))
                let height = panel.frame.height
                if editing ? height < previousHeight - 1 : height > previousHeight + 1 {
                    failures.append("HUD reverses resize direction while editing=\(editing)")
                }
                previousHeight = height
                intermediateHeights.insert(Int(height.rounded()))
            }
            maxFooterDrift = abs(try footerOffset(in: view) - originalFooter)
            maxHeaderDrift = max(maxHeaderDrift, abs(try headerOffset(in: view) - originalHeader))
            print("HUB_HUD_RESULT editing=\(editing) frame=\(panel.frame) topDrift=\(maxTopDrift) headerDrift=\(maxHeaderDrift) footerDrift=\(maxFooterDrift)")
            if editing, panel.frame.height < original.height + 30 {
                failures.append("Manage Tools does not expand to reveal its tray")
            }
            if intermediateHeights.count < 3, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                failures.append("HUD snaps to its new height without intermediate animation frames")
            }
            if maxTopDrift > 1 { failures.append("HUD top edge moves \(maxTopDrift) points") }
            if maxHeaderDrift > 1 { failures.append("HUD header moves \(maxHeaderDrift) points inside the window") }
            if maxFooterDrift > 3 { failures.append("HUD footer separates from its bottom edge by \(maxFooterDrift) points") }
            if !editing, abs(panel.frame.height - original.height) > 1 {
                failures.append("HUD does not return to its original height")
            }
            try capture(view, name: "hud-editing-\(editing)", output: output)
            if iteration == 3 {
                if launcher.editingOptionsItem != nil {
                    failures.append("Done leaves an invisible options editor active")
                }
                guard let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                    characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false,
                    keyCode: UInt16(kVK_Escape)) else { throw CocoaError(.coderInvalidValue) }
                _ = launcher.handlePanelKey(escape)
                if panel.isVisible { failures.append("Escape after Done does not dismiss the HUD") }
                launcher.prepareForPresentation()
                launcher.position(panel)
                panel.orderFrontRegardless()
                settle(view)
            }
        }
        for editing in [true, false, true, false] {
            withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = editing }
            RunLoop.main.run(until: Date().addingTimeInterval(0.06))
        }
        settle(view)
        if abs(panel.frame.maxY - original.maxY) > 1 || abs(panel.frame.height - original.height) > 1 {
            failures.append("Rapid edit reversals do not restore the original HUD geometry")
        }
        // Regression: the native panel grows/shrinks from its bottom edge,
        // while the shared header stays stationary during the page crossfade.
        let openingTop = panel.frame.maxY
        let openingHandleTop = dragHandleTop(handle, in: panel)
        launcher.activeUtility = .urlCleaner
        var maxOpeningTopDrift: CGFloat = 0
        var maxOpeningHeaderDrift: CGFloat = 0
        let openingDeadline = Date().addingTimeInterval(0.65)
        while Date() < openingDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 120))
            view.layoutSubtreeIfNeeded()
            maxOpeningTopDrift = max(maxOpeningTopDrift, abs(panel.frame.maxY - openingTop))
            let handleTop = dragHandleTop(handle, in: panel)
            maxOpeningHeaderDrift = max(maxOpeningHeaderDrift, abs(handleTop - openingHandleTop))
        }
        if maxOpeningTopDrift > 1 {
            failures.append("HUD top edge moves when opening a subpage")
        }
        if maxOpeningHeaderDrift > 1 {
            failures.append("HUD shared header moves when opening a subpage")
        }
        settle(view)
        let utilityHeight = panel.frame.height
        let returnTop = panel.frame.maxY
        let returnHandleTop = dragHandleTop(handle, in: panel)
        launcher.closeUtility()
        var intermediateReturnHeights = Set<Int>()
        var maxReturnTopDrift: CGFloat = 0
        var maxReturnHeaderDrift: CGFloat = 0
        var lastReturnHeight = utilityHeight
        var returnReversedDirection = false
        let rootIsTaller = original.height > utilityHeight
        let returnDeadline = Date().addingTimeInterval(0.85)
        while Date() < returnDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 120))
            view.layoutSubtreeIfNeeded()
            let height = panel.frame.height
            maxReturnTopDrift = max(maxReturnTopDrift, abs(panel.frame.maxY - returnTop))
            let currentHandleTop = dragHandleTop(handle, in: panel)
            maxReturnHeaderDrift = max(maxReturnHeaderDrift, abs(currentHandleTop - returnHandleTop))
            if rootIsTaller ? height < lastReturnHeight - 1 : height > lastReturnHeight + 1 {
                returnReversedDirection = true
            }
            lastReturnHeight = height
            if abs(height - utilityHeight) > 1, abs(height - original.height) > 1 {
                intermediateReturnHeights.insert(Int(height.rounded()))
            }
        }
        if abs(original.height - utilityHeight) > 12,
           intermediateReturnHeights.count < 3,
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            failures.append("Subpage return cuts to the root height instead of growing/shrinking smoothly")
        }
        if returnReversedDirection { failures.append("HUD reverses height direction during subpage return") }
        if maxReturnTopDrift > 1 { failures.append("HUD top edge moves during subpage return") }
        if maxReturnHeaderDrift > 1 { failures.append("HUD shared header moves during subpage return") }
        if abs(panel.frame.height - original.height) > 1 {
            failures.append("HUD does not settle at the root height after closing a subpage")
        }
        // The root can have more tools than fit on the screen. Its scroll
        // viewport must keep the native panel within the visible desktop,
        // with the same rounded layer mask throughout the transition.
        let visibleScreen = panel.screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        if panel.frame.minY < visibleScreen.minY + 15 {
            failures.append("HUD grows below the visible screen while returning to root")
        }
        if let contentLayer = panel.contentView?.layer {
            if contentLayer.cornerRadius < 21 || !contentLayer.masksToBounds {
                failures.append("HUD loses its rounded native content mask")
            }
        } else {
            failures.append("HUD has no native content mask")
        }
        launcher.activeUtility = .urlCleaner
        settle(view)
        launcher.hide()
        launcher.prepareForPresentation()
        let anchor = NSRect(x: original.midX - 20, y: original.maxY, width: 40, height: 20)
        launcher.position(panel, anchoredBelow: anchor)
        let reopeningFrame = panel.frame
        panel.orderFrontRegardless()
        settle(view)
        if abs(panel.frame.height - original.height) > 1 || abs(panel.frame.height - reopeningFrame.height) > 1
            || abs(panel.frame.maxY - anchor.minY + 6) > 1 {
            failures.append("Reopening after a utility clips or snaps the anchored HUD")
        }
    }

    // Measure the drag handle in screen coordinates, independent of the
    // NSPanel's changing height during presentation tests.
    private static func dragHandleTop(_ handle: NSView, in panel: NSPanel) -> CGFloat {
        panel.frame.minY + handle.convert(handle.bounds, to: nil).maxY
    }

    private static func descendant(_ identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier { return view }
        return view.subviews.lazy.compactMap { descendant(identifier, in: $0) }.first
    }

    // The close glyph is stable in both modes. Measuring its rendered top
    // catches movement inside a window whose AppKit frame itself stays fixed.
    private static func headerOffset(in view: NSView) throws -> CGFloat {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.coderInvalidValue)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
        for y in 0..<min(bitmap.pixelsHigh, Int(80 * scale)) {
            for x in Int(20 * scale)..<Int(38 * scale) {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   min(color.redComponent, color.greenComponent, color.blueComponent) > 0.5,
                   abs(color.redComponent - color.blueComponent) < 0.05 {
                    return CGFloat(y) / scale
                }
            }
        }
        throw CocoaError(.coderInvalidValue)
    }

    private static func footerOffset(in view: NSView) throws -> CGFloat {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.coderInvalidValue)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
        for distance in 0..<min(bitmap.pixelsHigh, Int(100 * scale)) {
            for x in Int(385 * scale)..<Int(402 * scale) {
                if let color = bitmap.colorAt(x: x, y: bitmap.pixelsHigh - distance - 1)?.usingColorSpace(.deviceRGB),
                   max(color.redComponent, color.greenComponent, color.blueComponent) > 0.3 {
                    return CGFloat(distance) / scale
                }
            }
        }
        throw CocoaError(.coderInvalidValue)
    }

    private static func settle(_ view: NSView) {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        view.layoutSubtreeIfNeeded()
        view.window?.displayIfNeeded()
    }

    private static func capture(_ view: NSView, name: String, output: URL) throws {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.coderInvalidValue)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.coderInvalidValue)
        }
        try png.write(to: output.appendingPathComponent(name + ".png"))
    }
}
#endif
