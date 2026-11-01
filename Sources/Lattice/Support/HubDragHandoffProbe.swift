#if LATTICE_DEVELOPMENT
import AppKit

enum HubDragHandoffProbe {
    static func run(source: HubDragView.DragView, host: NSView) throws {
        guard let config = source.configuration, let tile = config.toolLayout?.frames.first,
              let window = source.window else { throw HubEditingProbe.failure("Missing native handoff source") }
        let recorder = RecordingHubDragView(frame: host.convert(source.bounds, from: source))
        recorder.configuration = config
        host.addSubview(recorder)
        defer { recorder.finishDrag(); recorder.removeFromSuperview() }
        for (index, delay) in [0.6, 0.02, 0.3].enumerated() {
            let pickup = CGPoint(x: tile.minX + tile.width * 0.3, y: tile.minY + tile.height * 0.4)
            let downPoint = recorder.convert(pickup, to: nil)
            let nextPoint = recorder.convert(CGPoint(x: pickup.x + 24, y: pickup.y + 8), to: nil)
            let time = ProcessInfo.processInfo.systemUptime
            guard let press = NSEvent.mouseEvent(with: .leftMouseDown, location: downPoint, modifierFlags: [],
                timestamp: time - delay, windowNumber: window.windowNumber, context: nil,
                eventNumber: index * 2, clickCount: 1, pressure: 1),
                  let moved = NSEvent.mouseEvent(with: .leftMouseDragged, location: nextPoint, modifierFlags: [],
                timestamp: time, windowNumber: window.windowNumber, context: nil,
                eventNumber: index * 2 + 1, clickCount: 1, pressure: 1) else {
                throw HubEditingProbe.failure("Cannot create native source events")
            }
            recorder.mouseDown(with: press)
            recorder.mouseDragged(with: moved)
            print("HUB_DRAG_HANDOFF event=\(recorder.receivedEvent?.type.rawValue ?? 999) frame=\(recorder.receivedFrame ?? .zero) delay=\(delay)"); fflush(stdout)
            try HubEditingProbe.require(recorder.receivedEvent === press,
                "AppKit must receive the original press event, even when the drag event arrives later")
            try HubEditingProbe.require(recorder.receivedFrame == tile,
                "The original tile frame must reach AppKit without a second pointer-offset translation")
            recorder.finishDrag()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
    }
}

/// Records inputs at the operating-system boundary; the production source
/// still handles mouse-down, the threshold, bitmap staging and session state.
private final class RecordingHubDragView: HubDragView.DragView {
    var receivedEvent: NSEvent?
    var receivedFrame: CGRect?
    override func startNativeDrag(with item: NSDraggingItem, event: NSEvent) {
        receivedEvent = event
        receivedFrame = item.draggingFrame
    }
}
#endif
