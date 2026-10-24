import Foundation

/// Exercise the production Settings transition without native windows or capture work.
enum IslandSettingsFocusTests {
    final class Panel {
        var acceptsKeyFocus = true
        var resigned = false
        func resignKey() { resigned = true }
    }
    final class Hover {
        var suppressed = false
        func close(pointerInside: Bool) { suppressed = pointerInside }
    }
    final class Service {
        var running = true
        var heldDrag = false
        var dragPlaceholder = false
        var panel: Panel? = Panel()
        let hoverState = Hover()
        var expanded = true
        func dismissForOutsideClick() { if !heldDrag { expanded = false } }
    }
    static func run(_ suite: TestSuite) {
        let stopped = Service()
        stopped.running = false
        stopped.heldDrag = true
        stopped.dragPlaceholder = true
        stopped.prepareForSettings()
        suite.expect(stopped.expanded && !stopped.heldDrag && !stopped.dragPlaceholder
                     && stopped.hoverState.suppressed,
                     "when Island is not running, prepareForSettings cleans up drag and hover without dismissing")
        let ordinary = Service()
        ordinary.heldDrag = true
        ordinary.dragPlaceholder = true
        ordinary.prepareForSettings()
        suite.expect(!ordinary.expanded && !ordinary.heldDrag && !ordinary.dragPlaceholder
                     && ordinary.hoverState.suppressed,
                     "explicit Settings navigation collapses Island even during an internal drag")
        let runtime = (try? String(contentsOfFile: "Sources/Vorssaint/App/FeatureRuntime.swift", encoding: .utf8)) ?? ""
        for (feature, owner) in [
            ("notchCalendar", "NotchCalendarService"), ("notchNotifications", "NotchNotificationService"),
            ("notchDownloads", "NotchDownloadService"), ("notchAgents", "AgentUsageService"),
            ("notchWatch", "NotchWatchService"), ("notchAccessories", "NotchAccessoryService")
        ] {
            suite.expect(runtime.contains(".\(feature): {\n            if !AppFeature.\(feature).isAvailable { \(owner).shared.stop() }"),
                         "removing \(feature) stops its service before suspended presentation can return")
        }
        let service = (try? String(contentsOfFile: "Sources/Vorssaint/Services/Notch/NotchService.swift", encoding: .utf8)) ?? ""
        let delegate = (try? String(contentsOfFile: "Sources/Vorssaint/App/AppDelegate.swift", encoding: .utf8)) ?? ""
        let host = (try? String(contentsOfFile: "Sources/Vorssaint/Services/Notch/NotchWindowHost.swift", encoding: .utf8)) ?? ""
        let opening = service.components(separatedBy: "    func open(_ module:").dropFirst().first?
            .components(separatedBy: "    func collapse()").first ?? ""
        suite.expect(opening.contains("panel.makeKey()") && !opening.contains("NSApp.activate(")
                     && host.contains(".nonactivatingPanel"),
                     "Island opening takes panel keyboard focus without activating other Lattice windows")
        suite.expect(delegate.contains("func openSettingsWindow() {\n        NotchService.shared.prepareForSettings()"),
                     "all Settings entry points dismiss Island before reusing or creating the window")
    }
}
