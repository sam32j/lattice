import Foundation

enum PermissionPortalRefreshTests {
    class State {
        let visiblePermissions: [AppPermission] = [.automationFinder, .automationTerminal, .automationSystemEvents]
        var automation: [Permissions.AutomationTarget: Permissions.AutomationStatus] = [:]
        var automationRefreshID: UUID?
        var isVisible = true
    }
    enum Permissions {
        enum AutomationTarget: CaseIterable { case finder, terminal, systemEvents }
        enum AutomationStatus { case granted, undetermined }
        static var reading = AutomationStatus.undetermined
        static func automationStatus(for target: AutomationTarget) -> AutomationStatus { reading }
    }
    enum DispatchQueue {
        enum QoS { case userInitiated }
        final class Queue {
            var work: [() -> Void] = []
            func async(execute: @escaping () -> Void) { work.append(execute) }
            func run(_ index: Int = 0) { work.remove(at: index)() }
        }
        static let background = Queue(), main = Queue()
        static func global(qos: QoS) -> Queue { background }
    }
    static func run(_ suite: TestSuite) {
        DispatchQueue.background.work = []; DispatchQueue.main.work = []
        Permissions.reading = .undetermined
        let portal = Portal()
        portal.refreshAutomation()
        DispatchQueue.background.run()
        portal.refreshAutomation()
        Permissions.reading = .granted
        DispatchQueue.background.run()
        DispatchQueue.main.run(1)
        suite.expect(portal.automation[.finder] == .granted,
                     "the completed consent refresh updates the displayed Automation status")
        DispatchQueue.main.run()
        suite.expect(portal.automation[.finder] == .granted && portal.automation[.terminal] == .granted && portal.automation[.systemEvents] == .granted,
                     "an older passive check cannot replace a newer Automation grant")
        portal.isVisible = false
        portal.refreshAutomation()
        suite.expect(DispatchQueue.background.work.isEmpty,
                     "a late request-completion callback cannot restart refresh after the portal disappears")
    }
}
