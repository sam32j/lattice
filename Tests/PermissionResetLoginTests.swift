import Foundation

enum PermissionResetLoginTests {
    enum Failure: Error { case refused }
    final class Service {
        enum Status { case enabled, notRegistered }
        var status = Status.enabled
        var fails = false
        var attempts = 0
        func unregister() throws {
            attempts += 1
            if fails { throw Failure.refused }
            status = .notRegistered
        }
    }
    enum SMAppService { static var mainApp = Service() }
    enum NotificationCenter {
        static var notifications = 0
        static let `default` = Center()
        struct Center {
            func post(name: Notification.Name, object: Any?) { notifications += 1 }
        }
    }
    enum DispatchQueue {
        static let main = Queue()
        struct Queue { func async(execute: () -> Void) { execute() } }
    }
    enum Host { static var defaults: UserDefaults! }

    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.permission-login.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        Host.defaults = defaults
        defer { defaults.removePersistentDomain(forName: domain) }
        SMAppService.mainApp = Service()
        NotificationCenter.notifications = 0
        defaults.set(true, forKey: DefaultsKey.launchAtLoginWanted)
        suite.expect(Host.detachLoginItem()
                     && !defaults.bool(forKey: DefaultsKey.launchAtLoginWanted)
                     && SMAppService.mainApp.status == .notRegistered
                     && NotificationCenter.notifications == 1,
                     "reset unregisters login, clears repair intent, and refreshes its Settings control")
        let alreadyOff = Service()
        alreadyOff.status = .notRegistered
        alreadyOff.fails = true
        SMAppService.mainApp = alreadyOff
        suite.expect(Host.detachLoginItem() && alreadyOff.attempts == 0,
                     "an absent login item is already detached and needs no native unregister call")
        let refused = Service()
        refused.fails = true
        SMAppService.mainApp = refused
        defaults.set(true, forKey: DefaultsKey.launchAtLoginWanted)
        suite.expect(!Host.detachLoginItem()
                     && !defaults.bool(forKey: DefaultsKey.launchAtLoginWanted),
                     "native unregister failure is observable and does not silently restore launch intent")
    }
}
