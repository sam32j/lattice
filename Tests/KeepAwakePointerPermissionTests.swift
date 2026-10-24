import Foundation

enum KeepAwakePointerPermissionTests {
    enum ReviewDefaults { static var current: UserDefaults! }

    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.pointer-permission.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        ReviewDefaults.current = defaults
        let service = Service()
        defer {
            service.stopMouseJiggleTimer()
            defaults.removePersistentDomain(forName: domain)
            ReviewDefaults.current = nil
            Service.permissionGranted = true
            Service.posted = []
        }
        defaults.set(true, forKey: DefaultsKey.keepAwakeMouseJiggleEnabled)
        Service.permissionGranted = true
        service.syncMouseJiggleTimer()
        suite.expect(service.mouseJiggleTimer != nil, "granted optional mouse jiggle schedules its timer")
        Service.permissionGranted = false
        service.syncMouseJiggleTimer()
        suite.expect(service.mouseJiggleTimer == nil && service.isActive,
                     "revocation stops only mouse jiggle, not the ordinary Keep Awake session")
        service.jiggleMousePointer()
        suite.expect(Service.posted.isEmpty, "missing access cannot post pointer movement")
        Service.permissionGranted = true
        service.jiggleMousePointer()
        suite.expect(Service.posted.count == 1, "granted pointer movement uses the production jiggle path")
        Service.permissionGranted = false
        service.pendingMouseReturn?.perform()
        suite.expect(Service.posted.count == 1, "revocation prevents the delayed return movement too")
        service.sessionPausedForScreenLock = true
        Service.permissionGranted = true
        service.jiggleMousePointer()
        suite.expect(Service.posted.count == 1, "locked sessions do not post pointer movement")
    }
}
