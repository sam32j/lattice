import Foundation

/// Production startup state against disposable preferences, without a network request.
enum UpdateInitializationTests {
    enum UserDefaults {
        static let standard = Foundation.UserDefaults(suiteName: "lattice.tests.update-init")!
    }
    static func run(_ suite: TestSuite) {
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: "lattice.tests.update-init")
        defer { defaults.removePersistentDomain(forName: "lattice.tests.update-init") }
        suite.expect(Service().state == .idle, "a first launch does not claim an update check succeeded")
        for date in [Date().addingTimeInterval(-60), Date().addingTimeInterval(-90_000),
                     Date().addingTimeInterval(3_600)] {
            defaults.set(date.timeIntervalSince1970, forKey: DefaultsKey.lastUpdateCheckTime)
            let service = Service()
            suite.expect(service.state == .idle && abs((service.lastChecked ?? .distantPast).timeIntervalSince(date)) < 0.001,
                         "a saved attempt time preserves history without claiming success or hiding an update")
        }
    }
}
