#if LATTICE_DEVELOPMENT
import AppKit

enum HubDragProbe {
    static func run(launcher: LatticeHubService) throws {
        let defaults = UserDefaults.standard
        defaults.set("screenshot,media,scratchpad,homebrew,clipboard,urlCleaner", forKey: DefaultsKey.quickLauncherItemOrder)
        defaults.set(false, forKey: AppFeature.homebrew.availabilityKey)
        launcher.hiddenItemsRaw = "media"
        defaults.set("media", forKey: DefaultsKey.quickLauncherHiddenItems)
        launcher.isEditing = true
        let session = HubDragSession(launcher: launcher)
        let original = defaults.string(forKey: DefaultsKey.quickLauncherItemOrder)
        session.begin(.tool(.screenshot))
        for after in [true, false, true, false] {
            session.point(to: HubDropTarget(item: .tool(.clipboard), after: after))
        }
        try HubEditingProbe.require(defaults.string(forKey: DefaultsKey.quickLauncherItemOrder) == original,
                                    "Hovering must not persist order or move destination tiles")
        session.cancel()
        try HubEditingProbe.require(session.active == nil && session.target == nil
            && defaults.string(forKey: DefaultsKey.quickLauncherItemOrder) == original,
            "Cancelling a drag must clear transient state without changing order")
        session.begin(.tool(.screenshot))
        try HubEditingProbe.require(session.commit(to: HubDropTarget(item: .tool(.clipboard), after: true)),
                                    "A valid insertion must complete")
        let stored = PanelLayout.itemOrder(LatticeHubItem.self, key: DefaultsKey.quickLauncherItemOrder)
        try HubEditingProbe.require(Array(stored.prefix(6)) == [.media, .scratchpad, .homebrew, .clipboard, .screenshot, .urlCleaner],
                                    "Drop must preserve hidden/unavailable entries while moving the visible tool")
        try HubEditingProbe.require(session.active == nil, "A completed drop must end the session")
        session.begin(.control(.cleaningMode))
        try HubEditingProbe.require(!session.canMove(to: .tool(.screenshot)), "Quick controls cannot enter workflow order")
        try HubEditingProbe.require(session.hideActive() && launcher.hiddenControls.contains(.cleaningMode),
                                    "Dragging a quick control to Available Tools must hide it")
        launcher.setControlHidden(.cleaningMode, false)
        try verifyScrolling()
        launcher.isEditing = false
        print("HUB_DRAG_OK")
    }

    private static func verifyScrolling() throws {
        let scroll = NSScrollView(frame: CGRect(x: 0, y: 0, width: 240, height: 120))
        let document = NSView(frame: CGRect(x: 0, y: 0, width: 1200, height: 600))
        let anchor = NSView(frame: document.bounds)
        document.addSubview(anchor)
        scroll.documentView = document
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 240, height: 120),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        defer { window.contentView = nil; window.close() }
        let clip = scroll.contentView
        let point = clip.convert(CGPoint(x: clip.bounds.maxX - 2, y: clip.bounds.midY), to: nil)
        let scroller = HubDragScrolling()
        scroller.update(anchor: anchor, screenPoint: window.convertPoint(toScreen: point))
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        try HubEditingProbe.require(clip.bounds.minX > 10, "A stationary drag near the edge must keep scrolling")
        scroller.stop()
        let stopped = clip.bounds.origin
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        try HubEditingProbe.require(clip.bounds.origin == stopped, "Drag cancellation must stop edge scrolling")
    }
}
#endif
