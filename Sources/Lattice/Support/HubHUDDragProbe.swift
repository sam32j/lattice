#if LATTICE_DEVELOPMENT
import AppKit

enum HubHUDDragProbe {
    static func run(launcher: LatticeHubService, output: URL) throws {
        let original = UserDefaults.standard.string(forKey: DefaultsKey.quickLauncherItemOrder)
        launcher.prepareForPresentation()
        let panel = launcher.ensurePanel()
        launcher.position(panel)
        panel.orderFrontRegardless()
        launcher.isEditing = true
        defer {
            launcher.isEditing = false
            panel.orderOut(nil)
            UserDefaults.standard.set(original, forKey: DefaultsKey.quickLauncherItemOrder)
            launcher.objectWillChange.send()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        guard let host = panel.contentView, launcher.visibleItems.count >= 8 else {
            throw HubEditingProbe.failure("HUD drag fixture needs eight visible tools")
        }
        let items = launcher.visibleItems
        let views = HubEditingProbe.descendants(host).compactMap { $0 as? HubDragView.DragView }
        guard let source = views.first(where: { $0.configuration?.destination == .tools }),
              let layout = source.configuration?.toolLayout,
              source.prepareDrag(at: CGPoint(x: layout.frames[7].midX, y: layout.frames[7].midY)) != nil else {
            throw HubEditingProbe.failure("Cannot pick up the eighth real HUD tool")
        }
        defer { source.finishDrag() }
        let destination = source
        let targetFrame = layout.frames[1]
        let point = destination.convert(CGPoint(x: targetFrame.minX + targetFrame.width * 0.75, y: targetFrame.midY), to: nil)
        let context = HubNativeDragContext(source: source, identifier: HubDragItem.tool(items[7]).identifier,
                                          operations: .move, location: point)
        try HubEditingProbe.require(HubNativeDrop.update(in: destination, context: context) == .move,
                                    "HUD's second slot must accept the eighth tool")
        let left = HubNativeDragContext(source: source, identifier: context.identifier, operations: .move,
            location: destination.convert(CGPoint(x: targetFrame.minX + targetFrame.width * 0.25, y: targetFrame.midY), to: nil))
        try HubEditingProbe.require(HubNativeDrop.update(in: destination, context: left) == .move
            && source.configuration?.session.targetIndex == 1,
            "Both halves of HUD slot two must use the same insertion slot")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        try HubEditingProbe.capture(host, output: output.appendingPathComponent("hud-insertion-preview.png"))
        try HubEditingProbe.require(source.configuration?.toolLayout == layout,
                                    "HUD targeting slots must stay fixed while the displayed tiles shift")
        try HubEditingProbe.require(HubNativeDrop.perform(in: destination, context: context), "HUD drop must commit")
        print("HUB_HUD_DROP eighthToolIndex=\(launcher.visibleItems.firstIndex(of: items[7]) ?? -1)"); fflush(stdout)
        try HubEditingProbe.require(launcher.visibleItems[1] == items[7],
                                    "Dragging tool 8 onto slot 2 must land in slot 2, including its right half")
        try HubEditingProbe.require(Array(launcher.visibleItems.prefix(8))
            == [items[0], items[7], items[1], items[2], items[3], items[4], items[5], items[6]],
            "Moving tool eight to slot two must preserve the intervening tool order")
        source.finishDrag()
        UserDefaults.standard.set(original, forKey: DefaultsKey.quickLauncherItemOrder)
        launcher.objectWillChange.send()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let start = CGPoint(x: layout.frames[1].midX, y: layout.frames[1].midY)
        try HubEditingProbe.require(source.prepareDrag(at: start) != nil, "HUD must allow another drag after dropping")
        let forward = HubNativeDragContext(source: source, identifier: HubDragItem.tool(items[1]).identifier,
            operations: .move, location: source.convert(CGPoint(x: layout.frames[7].midX, y: layout.frames[7].midY), to: nil))
        try HubEditingProbe.require(HubNativeDrop.update(in: source, context: forward) == .move
            && HubNativeDrop.perform(in: source, context: forward) && launcher.visibleItems[7] == items[1],
            "HUD's forward insertion must also commit to the highlighted final slot")
        try HubEditingProbe.require(Array(launcher.visibleItems.prefix(8))
            == [items[0], items[2], items[3], items[4], items[5], items[6], items[7], items[1]],
            "Forward insertion must shift intervening tools toward the vacated slot")
        source.finishDrag()
    }
}
#endif
