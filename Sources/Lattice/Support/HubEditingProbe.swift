#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI
import Combine

/// Production presentation and persistence boundaries, with isolated defaults.
enum HubEditingProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier,
              identity.hasPrefix("io.github.sam32j.lattice.tests."),
              let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(CommandLine.arguments.contains("--preview") ? .regular : .accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        let defaults = UserDefaults.standard
        defaults.register(defaults: Defaults.registeredDefaults)
        defaults.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        for feature in AppFeature.allCases {
            SettingsRefactorProbe.setPreviewAvailability(feature, enabled: false)
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        let launcher = LatticeHubService.shared
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try require(launcher.enabledCount == 0 && launcher.canManageTools,
                        "Quick controls alone must keep Manage Tools available")
            launcher.setControlHidden(.cleaningMode, true)
            try require(launcher.canManageTools, "Hidden quick controls must remain manageable")
            launcher.setControlHidden(.cleaningMode, false)
            for item in LatticeHubItem.allCases {
                SettingsRefactorProbe.setPreviewAvailability(item.feature, enabled: true)
                for key in item.feature.enabledKeys { defaults.set(true, forKey: key) }
            }
            for feature in [AppFeature.quickLauncher, .micMute, .keepAwake, .commandBar, .brightness] {
                SettingsRefactorProbe.setPreviewAvailability(feature, enabled: true)
            }
            try HubColdDragProbe.run()
            try HubPageLayoutProbe.run(output: output)
            try HubDragProbe.run(launcher: launcher)
            SettingsRefactorProbe.setPreviewAvailability(AppFeature.homebrew, enabled: true)
            launcher.hiddenItemsRaw = "wallpaper,media,homebrew,clipboard,urlCleaner,scratchpad"
            defaults.set(launcher.hiddenItemsRaw, forKey: DefaultsKey.quickLauncherHiddenItems)
            try HubHUDDragProbe.run(launcher: launcher, output: output)
            for size in [CGSize(width: 300, height: 282), CGSize(width: 424, height: 282), CGSize(width: 504, height: 282)] {
                try verifyView(size: size, output: output, preview: CommandLine.arguments.contains("--preview"))
            }
            launcher.hiddenItemsRaw = ""
            try verifyView(size: CGSize(width: 424, height: 282), output: output, preview: false)
            try verifyIsland(output: output)
            try verifySparseAlignment()
            try verifyEmptyState(output: output)
            defaults.removePersistentDomain(forName: identity)
            print("HUB_EDITOR_OK")
            exit(0)
        } catch {
            defaults.removePersistentDomain(forName: identity)
            print("HUB_EDITOR_FAILED \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func verifySparseAlignment() throws {
        let launcher = LatticeHubService.shared
        launcher.prepareForPresentation()
        launcher.hiddenItemsRaw = LatticeHubItem.allCases.filter {
            ![LatticeHubItem.screenshot, .screenRecorder, .recentCaptures].contains($0)
        }.map(\.rawValue).joined(separator: ",")
        let size = CGSize(width: 504, height: 180)
        let host = NSHostingView(rootView: LatticeHubView(notchSize: size).background(Color.black))
        host.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 180, y: 180), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        settle(host)
        guard let first = itemFrames(in: host)["hub-drag-tool:screenshot"] else { throw failure("Missing sparse rail cell") }
        try require(abs(first.minX) < 1, "A sparse rail must begin at its leading edge, got \(first)")
        launcher.isEditing = true
        settle(host)
        guard let edited = itemFrames(in: host)["hub-drag-tool:screenshot"] else { throw failure("Missing sparse edit cell") }
        try require(abs(edited.minX) < 1, "Sparse editing must preserve leading alignment")
        launcher.isEditing = false
        print("HUB_SPARSE_ALIGNMENT_OK")
    }

    private static func verifyView(size: CGSize, output: URL, preview: Bool) throws {
        let launcher = LatticeHubService.shared
        launcher.prepareForPresentation()
        let host = NSHostingView(rootView: LatticeHubView(notchSize: size).environment(\.colorScheme, .dark)
            .background(Color.black))
        host.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 180, y: 180), size: size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Hub Drag Fixture"
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        settle(host)
        let normal = itemFrames(in: host)
        launcher.isEditing = true
        settle(host)
        let editing = itemFrames(in: host)
        try require(!normal.isEmpty, "Production rail must expose native drag cells")
        for (id, frame) in normal {
            guard let next = editing[id] else { continue }
            try require(abs(frame.minX - next.minX) < 1 && abs(frame.minY - next.minY) < 1,
                        "Editing changed the display position of \(id) at \(size)")
        }
        guard let tray = descendants(host).first(where: { $0.identifier?.rawValue == "hub-hidden-tray" }) else {
            throw failure("Available Tools must have a reachable drop zone")
        }
        let frame = host.convert(tray.bounds, from: tray)
        print("HUB_EDITOR_STATE hidden=\(launcher.hiddenItems.count) editing=\(launcher.isEditing) presented=\(launcher.editingPresentation.isPresented) expanded=\(launcher.editingPresentation.isExpanded)")
        try require(host.bounds.insetBy(dx: -1, dy: -1).contains(frame) && tray.visibleRect.height >= 35,
                    "Available Tools is cut off at \(size): \(frame), visible=\(tray.visibleRect)")
        try capture(host, output: output.appendingPathComponent("editor-\(Int(size.width))-\(Int(size.height)).png"))
        if size.width == 300, !preview { try HubTrayClippingProbe.run(host: host, output: output) }
        for scroll in descendants(host).compactMap({ $0 as? NSScrollView }) {
            if let document = scroll.documentView {
                try require(document.bounds.height <= scroll.contentView.bounds.height + 1,
                            "Hub grid must not provide vertical scrolling instead of enough height")
            }
        }
        if size.width == 424, !preview { try HubNativeDragProbe.run(host: host, launcher: launcher, output: output) }
        if preview, size.width == 424 {
            try runPreview(window: window, host: host)
            return
        }
        launcher.isEditing = false
        settle(host)
        let finished = itemFrames(in: host)
        for (id, frame) in normal {
            guard let next = finished[id] else { continue }
            try require(abs(frame.minX - next.minX) < 1 && abs(frame.minY - next.minY) < 1,
                        "Done changed the displayed tool order")
        }
        print("HUB_EDITOR_GEOMETRY size=\(size) tray=\(frame) cells=\(normal.count)")
    }

    private static func runPreview(window: NSWindow, host: NSView) throws {
        guard let session = descendants(host).compactMap({ ($0 as? HubDragView.DragView)?.configuration?.session }).first else {
            throw failure("Preview has no production drag session")
        }
        let observer = session.$active.sink { _ in
            DispatchQueue.main.async {
                let order = UserDefaults.standard.string(forKey: DefaultsKey.quickLauncherItemOrder) ?? ""
                print("HUB_NATIVE_DRAG active=\(session.active?.identifier ?? "idle") order=\(order)")
                fflush(stdout)
            }
        }
        let delegate = HubPreviewWindowDelegate()
        window.delegate = delegate
        NSApp.activate(ignoringOtherApps: true)
        print("HUB_EDITOR_PREVIEW_READY"); fflush(stdout)
        let timeout = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { _ in window.close() }
        NSApp.run()
        timeout.invalidate()
        observer.cancel()
        window.delegate = nil
        withExtendedLifetime(delegate) {}
        session.cancel()
    }

    private static func verifyEmptyState(output: URL) throws {
        let launcher = LatticeHubService.shared
        launcher.prepareForPresentation()
        launcher.hiddenItemsRaw = LatticeHubItem.allCases.map(\.rawValue).joined(separator: ",")
        for scenario in 0..<3 {
            let hideControls = scenario != 0
            if scenario == 2 {
                for item in LatticeHubItem.allCases {
                    SettingsRefactorProbe.setPreviewAvailability(item.feature, enabled: false)
                    for key in item.feature.enabledKeys { UserDefaults.standard.set(false, forKey: key) }
                }
                try require(launcher.enabledCount == 0 && launcher.canManageTools,
                            "Hidden quick controls alone keep the empty-state restore action available")
            }
            if hideControls {
                for action in HubControlAction.allCases { launcher.setControlHidden(action, true) }
            }
            let height = NotchService.shared.expandedGeometry.hubContentHeight(toolCount: 0,
                controlsHeight: launcher.notchControlsHeight, editing: false)
            try require(height >= 160 && launcher.canManageTools, "An empty hub must retain its state and restore action")
            let size = CGSize(width: 424, height: height)
            let host = NSHostingView(rootView: LatticeHubView(notchSize: size)
                .environment(\.colorScheme, .dark).background(Color.black))
            host.sizingOptions = []
            let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 180, y: 180), size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            settle(host)
            let name = scenario == 2 ? "empty-controls-only-hidden" : "empty-controls-hidden-\(hideControls)"
            try capture(host, output: output.appendingPathComponent(name + ".png"))
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        print("HUB_EMPTY_STATE_OK")
    }

    private static func verifyIsland(output: URL) throws {
        let defaults = UserDefaults.standard
        SettingsRefactorProbe.setPreviewAvailability(AppFeature.notch, enabled: true)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(NotchModule.allCases.filter { $0 != .hub }.map(\.rawValue).joined(separator: ","),
                     forKey: DefaultsKey.notchHiddenModules)
        let island = NotchService.shared
        let launcher = LatticeHubService.shared
        defer { island.stop(); defaults.set(false, forKey: DefaultsKey.notchEnabled) }
        island.open(.hub)
        guard let view = island.presentationWindow?.contentView else { throw failure("Island did not open") }
        settle(view)
        let normal = island.contentSize.height
        launcher.isEditing = true
        try require(launcher.editingPresentation.isExpanded,
                    "Editor crossfade must start with the island resize, without waiting for it to settle")
        settle(view)
        try require(launcher.editingPresentation.isExpanded, "Island must make room and reveal its editor")
        guard let tray = descendants(view).first(where: { $0.identifier?.rawValue == "hub-hidden-tray" }) else {
            throw failure("Native island editor has no hide destination")
        }
        print("HUB_NATIVE_TRAY frame=\(view.convert(tray.bounds, from: tray)) visible=\(tray.visibleRect) host=\(view.bounds)"); fflush(stdout)
        try require(tray.visibleRect.height >= 35, "Native island must expose the whole Available Tools destination")
        try capture(view, output: output.appendingPathComponent("actual-island-editor.png"))
        try HubTrayClippingProbe.verifyVisibleTitle(host: view, tray: tray)
        let editing = island.contentSize.height
        try require(abs(editing - normal - 60) < 1, "Island editor must use the shared rail plus its bounded strip")
        launcher.isEditing = false
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            try require(launcher.editingPresentation.isPresented,
                        "Island must retain its editor size until outgoing content collapses")
            try require(abs(island.contentSize.height - editing) < 1,
                        "Island shrinks before its editing strip closes")
        }
        settle(view)
        try require(!launcher.editingPresentation.isPresented && abs(island.contentSize.height - normal) < 1,
                    "Island must return to its normal height after the strip closes")
        print("HUB_EDITOR_ISLAND normal=\(normal) editing=\(editing)")
    }

    static func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private static func itemFrames(in host: NSView) -> [String: CGRect] {
        var result = [String: CGRect]()
        for view in descendants(host) {
            if let strip = view as? HubDragView.DragView,
               let config = strip.configuration, config.destination == .tools, let layout = config.toolLayout {
                for (index, item) in config.toolItems.enumerated() {
                    let center = CGPoint(x: layout.frames[index].midX, y: layout.frames[index].midY)
                    if let entry = strip.source(at: center) {
                        result["hub-drag-tool:\(item.rawValue)"] = host.convert(entry.rect, from: strip)
                    }
                }
            }
            guard let id = view.identifier?.rawValue, id.hasPrefix("hub-drag-tool:") else { continue }
            result[id] = host.convert(view.bounds, from: view)
        }
        return result
    }
    private static func settle(_ view: NSView) {
        RunLoop.main.run(until: Date().addingTimeInterval(0.9))
        view.layoutSubtreeIfNeeded()
    }
    static func failure(_ message: String) -> NSError {
        NSError(domain: "HubEditingProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw failure(message) }
    }
    static func capture(_ view: NSView, output: URL) throws {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw failure("No editor bitmap") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw failure("No editor PNG") }
        try png.write(to: output)
    }
}

private final class HubPreviewWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.stop(nil)
        if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
            NSApp.postEvent(event, atStart: true)
        }
    }
}
#endif
