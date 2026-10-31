import AppKit
import Combine

enum KeepAwakePreferenceObserverTests {
    enum NSWorkspace {
        static let shared = Workspace()
        static let didWakeNotification = Notification.Name("lattice.tests.didWake")
    }
    final class Workspace { let notificationCenter = NotificationCenter() }
    final class Service {
        static let preferenceCenter = NotificationCenter()
        var defaultsObserver: AnyCancellable?
        var wakeObserver: NSObjectProtocol?
        var preferenceSyncScheduled = false
        var syncs = 0
        func refreshPasswordlessStatus() {}
        func syncWithPreferences() { syncs += 1 }
    }
    static func run(_ suite: TestSuite) {
        let service = Service()
        service.startPreferenceObservation()
        service.startPreferenceObservation()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        suite.expect(service.syncs == 1, "one wake reconciles an active Stay Awake session exactly once")
        service.stopPreferenceObservation()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        suite.expect(service.syncs == 1 && service.defaultsObserver == nil && service.wakeObserver == nil,
                     "disabled Stay Awake retires wake and preference observers")
        service.startPreferenceObservation()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        suite.expect(service.syncs == 2, "re-enabling restores wake reconciliation without duplicate observation")
        service.stopPreferenceObservation()
    }
}
