// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The production scan entry point, with inert app discovery and source APIs.
enum AppUpdateScanProgressTests {
    enum UserDefaults {
        static let name = "vorss.tests.app-update-progress.\(UUID().uuidString)"
        static let standard = Foundation.UserDefaults(suiteName: name)!
    }
    struct AppFeature {
        static let appUpdates = AppFeature()
        var isAvailable: Bool { true }
    }
    class State {
        var sourceRefreshWorkItem: DispatchWorkItem?
        var sourceRefreshPending = false
        var automaticCheckPending = false
        var isChecking = false
        var lastError: String?
        var checkedAppsCount = 0
        var totalAppsCount = 0
        var items: [AppUpdatesSupport.Item] = []
        var rules: [AppUpdatesSupport.UpdateRule] = []
        var scanGeneration = 0
        var checkCancellation: AppUpdateCheckCancellation?
        let workQueue = DispatchQueue(label: "app-updates-progress.tests")
        var sourceCompletion: ((Service.SourceResult) -> Void)?
        var finished = false
        static var apps: [AppUpdatesSupport.InstalledApp] = []
        static let discoveryGate = DispatchSemaphore(value: 0)

        func reloadRules() {}
        static func scanInstalledApps(includePublisherFeeds: Bool,
                                      cancellation: AppUpdateCheckCancellation) -> [AppUpdatesSupport.InstalledApp] {
            discoveryGate.wait()
            return apps
        }
        func packageManagerFindings(apps: [AppUpdatesSupport.InstalledApp], includeUpdates: Bool,
                                   cancellation: AppUpdateCheckCancellation) -> Service.PackageResult {
            .init(items: [], coveredPaths: Set(apps.map(\.path)), available: true, onlineCoverageAvailable: true)
        }
        func storeFindings(for apps: [AppUpdatesSupport.InstalledApp], country: String?,
                           operatingSystemVersion: String, cancellation: AppUpdateCheckCancellation,
                           completion: @escaping (Service.SourceResult) -> Void) {
            DispatchQueue.main.async { self.sourceCompletion = completion }
        }
        func publisherFindings(for apps: [AppUpdatesSupport.InstalledApp], operatingSystemVersion: String,
                               cancellation: AppUpdateCheckCancellation,
                               completion: @escaping (Service.SourceResult) -> Void) { completion(.init(items: [], available: true)) }
        func onlineCatalogFindings(for apps: [AppUpdatesSupport.InstalledApp], operatingSystemVersion: String,
                                   forceRefresh: Bool, cancellation: AppUpdateCheckCancellation,
                                   completion: @escaping (Service.SourceResult) -> Void) { completion(.init(items: [], available: true)) }
        func appendUpdate(_ item: AppUpdatesSupport.Item, rules: [AppUpdatesSupport.UpdateRule]) { items.append(item) }
        func finishCheck(items: [AppUpdatesSupport.Item], packageManagerAvailable: Bool,
                         onlineCatalogAvailable: Bool, appStoreAvailable: Bool, uncheckedAppNames: [String],
                         uncomparableAppNames: [String], automatic: Bool) { finished = true; isChecking = false }
    }

    static func run(_ suite: TestSuite) {
        defer { UserDefaults.standard.removePersistentDomain(forName: UserDefaults.name) }
        UserDefaults.standard.set(true, forKey: DefaultsKey.appUpdatesIncludeHomebrewApps)
        UserDefaults.standard.set(false, forKey: DefaultsKey.appUpdatesIncludeAppStore)
        UserDefaults.standard.set(false, forKey: DefaultsKey.appUpdatesIncludeOnlineCatalog)
        State.apps = (0..<8).map {
            .init(name: "App \($0)", bundleID: "test.app.\($0)", path: "/Fixture/\($0).app",
                  version: "1", isFromAppStore: false)
        }
        let service = Service()
        service.check()
        suite.expect(service.isChecking && service.totalAppsCount == 0 && service.checkedAppsCount == 0,
                     "a first scan reports no invented total before discovery")
        State.discoveryGate.signal()
        wait { service.sourceCompletion != nil }
        suite.expect(service.totalAppsCount == 8 && service.checkedAppsCount == 0,
                     "discovery publishes its real total without estimating completed app checks")
        service.sourceCompletion?(.init(items: [], available: true))
        wait { service.finished }
        suite.expect(service.checkedAppsCount == 0,
                     "a source callback never invents a three-quarter app count")
        service.totalAppsCount = 99
        service.finished = false
        service.sourceCompletion = nil
        service.check()
        suite.expect(service.totalAppsCount == 0,
                     "a new scan does not reuse a previous source selection's total")
        State.discoveryGate.signal()
        wait { service.sourceCompletion != nil }
        service.sourceCompletion?(.init(items: [], available: true))
        wait { service.finished }
    }

    static func wait(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(3)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
        }
    }
}
