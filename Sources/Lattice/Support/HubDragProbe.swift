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
        for index in [2, 1, 2, 1] { session.point(toIndex: index) }
        try HubEditingProbe.require(defaults.string(forKey: DefaultsKey.quickLauncherItemOrder) == original,
                                    "Hovering must not persist order or move destination tiles")
        session.cancel()
        try HubEditingProbe.require(session.active == nil && session.targetIndex == nil
            && defaults.string(forKey: DefaultsKey.quickLauncherItemOrder) == original,
            "Cancelling a drag must clear transient state without changing order")
        session.begin(.tool(.screenshot))
        try HubEditingProbe.require(session.commit(toIndex: 2),
                                    "A valid insertion must complete")
        let stored = PanelLayout.itemOrder(LatticeHubItem.self, key: DefaultsKey.quickLauncherItemOrder)
        try HubEditingProbe.require(Array(stored.prefix(6)) == [.media, .scratchpad, .homebrew, .clipboard, .screenshot, .urlCleaner],
                                    "Drop must preserve hidden/unavailable entries while moving the visible tool")
        try HubEditingProbe.require(session.active == nil, "A completed drop must end the session")
        session.begin(.control(.cleaningMode))
        session.point(toIndex: 0)
        try HubEditingProbe.require(session.targetIndex == nil && !session.commit(toIndex: 0),
                                    "Quick controls cannot enter workflow order")
        try HubEditingProbe.require(session.hideActive() && launcher.hiddenControls.contains(.cleaningMode),
                                    "Dragging a quick control to Available Tools must hide it")
        launcher.setControlHidden(.cleaningMode, false)
        try verifyScrolling()
        try verifyFeedback(launcher: launcher)
        launcher.isEditing = false
        print("HUB_DRAG_OK")
    }

    private static func verifyFeedback(launcher: LatticeHubService) throws {
        var time: TimeInterval = 10
        var pulses = 0
        let session = HubDragSession(launcher: launcher, now: { time }, performHaptic: { pulses += 1 })
        session.begin(.tool(.screenshot))
        session.point(toIndex: 0)
        for index in [1, 2, 1, 2] { session.point(toIndex: index) }
        print("HUB_HAPTIC_BURST pulses=\(pulses)"); fflush(stdout)
        try HubEditingProbe.require(pulses == 1, "A rapid tile-crossing burst must give one haptic, not several")
        time += 0.2
        session.point(toIndex: 3)
        try HubEditingProbe.require(pulses == 2, "A later deliberate target change must retain feedback")
        session.cancel()
        session.begin(.tool(.screenshot))
        session.point(toIndex: 0)
        session.point(toIndex: 1)
        time += 0.2
        session.point(toIndex: 1)
        try HubEditingProbe.require(pulses == 3, "Staying in one destination slot must not repeat feedback")
        session.cancel()
        session.begin(.tool(.screenshot))
        session.point(toIndex: 0)
        session.point(toIndex: 1)
        try HubEditingProbe.require(pulses == 4, "A new drag must start with fresh haptic feedback")
        session.cancel()
        session.begin(.tool(.screenshot))
        session.point(toIndex: 0)
        session.point(toIndex: 1)
        session.pointToHiddenTray(true)
        try HubEditingProbe.require(pulses == 6,
            "Entering the hide zone must give one haptic even immediately after a reorder alignment")
        for _ in 0..<1000 { session.pointToHiddenTray(true) }
        try HubEditingProbe.require(pulses == 6, "Staying in the hide zone must not repeat its entry haptic")
        session.pointToHiddenTray(false)
        time += 0.2
        session.pointToHiddenTray(true)
        try HubEditingProbe.require(pulses == 7, "A later hide-zone reentry must provide feedback again")
        session.pointToHiddenTray(false)
        session.pointToHiddenTray(true)
        try HubEditingProbe.require(pulses == 7, "Rapid hide-zone boundary jitter must not repeat feedback")
        session.cancel()
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
