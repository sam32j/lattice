#if LATTICE_DEVELOPMENT
import AppKit

/// This runs before any HUD or drag preview has warmed the rendering path.
enum HubColdDragProbe {
    static func run() throws {
        let defaults = UserDefaults.standard
        SettingsRefactorProbe.setPreviewAvailability(AppFeature.notch, enabled: true)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(NotchModule.allCases.filter { $0 != .hub }.map(\.rawValue).joined(separator: ","),
                     forKey: DefaultsKey.notchHiddenModules)
        let island = NotchService.shared
        let launcher = LatticeHubService.shared
        defer { island.stop(); defaults.set(false, forKey: DefaultsKey.notchEnabled) }
        island.open(.hub)
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        launcher.isEditing = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let host = island.presentationWindow?.contentView,
              let source = HubEditingProbe.descendants(host).compactMap({ $0 as? HubDragView.DragView })
                .first(where: { $0.configuration?.destination == .tools }),
              let rect = source.configuration?.toolLayout?.frames.first,
              let window = source.window else { throw HubEditingProbe.failure("Cold island has no drag surface") }
        let pickup = CGPoint(x: rect.midX, y: rect.midY)
        for attempt in 0..<3 {
            let origin = window.convertPoint(toScreen: source.convert(.zero, to: nil))
            let began = ProcessInfo.processInfo.systemUptime
            guard source.prepareDrag(at: pickup) != nil else {
                throw HubEditingProbe.failure("Cold island cannot prepare a tile drag")
            }
            let milliseconds = (ProcessInfo.processInfo.systemUptime - began) * 1000
            var drift: CGFloat = 0
            let deadline = Date().addingTimeInterval(0.2)
            while Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 120))
                let next = window.convertPoint(toScreen: source.convert(.zero, to: nil))
                drift = max(drift, hypot(next.x - origin.x, next.y - origin.y))
            }
            print("HUB_COLD_PICKUP attempt=\(attempt) prepareMs=\(milliseconds) sourceDrift=\(drift)"); fflush(stdout)
            source.finishDrag()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
        try HubDragHandoffProbe.run(source: source, host: host)
    }
}
#endif
