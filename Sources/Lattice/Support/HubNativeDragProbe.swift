#if LATTICE_DEVELOPMENT
import AppKit
import Combine

enum HubNativeDragProbe {
    static func run(host: NSView, launcher: LatticeHubService, output: URL) throws {
        let views = HubEditingProbe.descendants(host).compactMap { $0 as? HubDragView.DragView }
        guard let strip = views.first(where: { $0.configuration?.destination == .tools }),
              let tray = views.first(where: { $0.configuration?.destination == .hiddenTray }),
              let config = strip.configuration, let layout = config.toolLayout, config.toolItems.count >= 3 else {
            throw HubEditingProbe.failure("Production native strip and hide destination are missing")
        }
        let session = config.session
        try HubEditingProbe.require(tray.configuration?.session === session,
                                    "The utility strip and hide tray must share one drag session")
        let original = UserDefaults.standard.string(forKey: DefaultsKey.quickLauncherItemOrder)
        let fullOrder = PanelLayout.itemOrder(LatticeHubItem.self, key: DefaultsKey.quickLauncherItemOrder)
        let item = config.toolItems[0]
        let start = CGPoint(x: layout.frames[0].midX, y: layout.frames[0].midY)
        try HubEditingProbe.require(host.hitTest(host.convert(start, from: strip)) === strip,
                                    "A real edit-mode mouse pickup must reach the native strip surface")
        guard let nativeItem = strip.prepareDrag(at: start) else {
            throw HubEditingProbe.failure("A real utility tile cannot prepare its native drag")
        }
        try HubEditingProbe.require(nativeItem.draggingFrame.size == layout.frames[0].size,
                                    "A utility drag preview must retain the tile's dimensions")
        try HubEditingProbe.require(nativeItem.draggingFrame == layout.frames[0],
                                    "Native pickup must use the original tile rect for AppKit's press-relative hotspot")
        try HubEditingProbe.require(session.active == .tool(item), "Utility pickup must activate shared hide feedback")
        let target = strip.convert(CGPoint(x: layout.frames[2].midX, y: layout.frames[2].midY), to: nil)
        let context = HubNativeDragContext(source: strip, identifier: HubDragItem.tool(item).identifier,
                                          operations: .move, location: target)
        var publications = 0
        let observer = session.$targetIndex.dropFirst().sink { _ in publications += 1 }
        for _ in 0..<1000 {
            try HubEditingProbe.require(HubNativeDrop.update(in: strip, context: context) == .move,
                                        "The native utility target must accept the shared source")
        }
        observer.cancel()
        try HubEditingProbe.require(publications == 1 && session.targetIndex == 2,
                                    "Repeated hover in one slot must produce one live-preview update")
        try HubEditingProbe.require(UserDefaults.standard.string(forKey: DefaultsKey.quickLauncherItemOrder) == original,
                                    "Native hover must not persist an order change")
        let boundary = strip.convert(CGPoint(x: (layout.frames[1].midX + layout.frames[2].midX) / 2,
                                             y: layout.frames[2].midY), to: nil).x
        for delta in [-1.0, 1.0, -1.0, 1.0] {
            let jitter = HubNativeDragContext(source: strip, identifier: context.identifier,
                operations: .move, location: CGPoint(x: boundary + delta, y: target.y))
            _ = HubNativeDrop.update(in: strip, context: jitter)
            try HubEditingProbe.require(session.targetIndex == 2,
                "Small pointer noise at a slot boundary must not reverse the insertion preview")
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        try HubEditingProbe.capture(host, output: output.appendingPathComponent("reorder-target.png"))
        try HubEditingProbe.require(HubNativeDrop.perform(in: strip, context: context), "Native strip drop must commit")
        try HubEditingProbe.require(launcher.visibleItems[2] == item, "Native drop must use the displayed slot index")
        let reordered = PanelLayout.itemOrder(LatticeHubItem.self, key: DefaultsKey.quickLauncherItemOrder)
        try HubEditingProbe.require(reordered.filter { $0 != item } == fullOrder.filter { $0 != item },
                                    "A native drop must preserve every other saved entry, including hidden tools")
        strip.finishDrag()
        UserDefaults.standard.set(original, forKey: DefaultsKey.quickLauncherItemOrder)
        launcher.objectWillChange.send()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        guard strip.prepareDrag(at: start) != nil else { throw HubEditingProbe.failure("Utility cannot be picked up again") }
        let hideContext = HubNativeDragContext(source: strip, identifier: HubDragItem.tool(item).identifier,
            operations: .move, location: tray.convert(CGPoint(x: tray.bounds.midX, y: tray.bounds.midY), to: nil))
        try HubEditingProbe.require(HubNativeDrop.update(in: tray, context: hideContext) == .move
            && session.targetsHiddenTray, "A dragged utility must highlight and be accepted by the hide zone")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        try HubEditingProbe.capture(host, output: output.appendingPathComponent("hide-feedback.png"))
        try HubEditingProbe.require(HubNativeDrop.perform(in: tray, context: hideContext)
            && launcher.hiddenItems.contains(item), "Dropping a utility in the native hide zone must hide it")
        strip.finishDrag()
        launcher.setHidden(item, false)

        guard let control = views.first(where: { view in
            guard let destination = view.configuration?.destination else { return false }
            if case .item(.control) = destination { return true }; return false
        }), let entry = control.source(at: CGPoint(x: control.bounds.midX, y: control.bounds.midY)),
           let image = HubTileDragPreview.image(in: control, rect: entry.rect, cornerRadius: 8),
           let toggleItem = control.prepareDrag(at: CGPoint(x: control.bounds.midX, y: control.bounds.midY)) else {
            throw HubEditingProbe.failure("A toggle cannot capture and prepare its actual tile")
        }
        try HubEditingProbe.require(toggleItem.draggingFrame.size == control.bounds.size
            && image.size == control.bounds.size, "Toggle preview must keep its actual width, height and aspect ratio")
        if let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data),
           let png = bitmap.representation(using: .png, properties: [:]) {
            try png.write(to: output.appendingPathComponent("toggle-tile-preview.png"))
        }
        let toggleContext = HubNativeDragContext(source: control, identifier: entry.item.identifier,
                                                 operations: .move, location: target)
        try HubEditingProbe.require(HubNativeDrop.update(in: strip, context: toggleContext).isEmpty,
                                    "Toggles must not enter the utility reorder layout")
        let toggleHide = HubNativeDragContext(source: control, identifier: entry.item.identifier,
            operations: .move, location: tray.convert(CGPoint(x: tray.bounds.midX, y: tray.bounds.midY), to: nil))
        try HubEditingProbe.require(HubNativeDrop.update(in: tray, context: toggleHide) == .move
            && session.targetsHiddenTray && HubNativeDrop.perform(in: tray, context: toggleHide),
            "A real native toggle drag must hide through the shared destination")
        control.finishDrag()
        if case .control(let action) = entry.item { launcher.setControlHidden(action, false) }
        try HubEditingProbe.require(session.active == nil && session.targetIndex == nil
            && !session.targetsHiddenTray, "Cancelling native pickup must clear every drag affordance")
        try verifyChangingInventory(strip: strip, launcher: launcher)
        print("HUB_NATIVE_ADAPTER_OK hoverPublications=\(publications) repeatUpdates=1000")
    }

    private static func verifyChangingInventory(strip: HubDragView.DragView, launcher: LatticeHubService) throws {
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard let config = strip.configuration, let layout = config.toolLayout,
              config.toolItems.count >= 3,
              strip.prepareDrag(at: CGPoint(x: layout.frames[0].midX, y: layout.frames[0].midY)) != nil else {
            throw HubEditingProbe.failure("Cannot prepare inventory-change drag")
        }
        let removed = config.toolItems[1]
        defer { launcher.setHidden(removed, false); strip.finishDrag() }
        config.session.point(toIndex: config.toolItems.count - 1)
        launcher.setHidden(removed, true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        try HubEditingProbe.require(config.session.active == nil && config.session.targetIndex == nil,
                                    "A changed visible inventory must cancel a drag with an obsolete final slot")
    }
}
#endif
