import Foundation

enum PageScheduleLifecycleTests {
    class CleanerState {
        let defaults: UserDefaults
        var settings: (frequency: CleanerSchedule.Frequency, hour: Int, minute: Int, weekday: Int)
            = (.daily, 9, 0, 2)
        var scheduled: [Date] = []
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func schedule(at date: Date) { scheduled.append(date) }
    }
    class UpdatesState {
        let defaults: UserDefaults
        var lastCheck: Date?
        var frequency = AppUpdatesSupport.CheckFrequency.daily
        var timer: Timer?
        var nextCheck: Date?
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func check(automatic: Bool) {}
    }
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.page-schedule.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: AppFeature.cleaner.availabilityKey)
        defaults.set(false, forKey: AppFeature.appUpdates.availabilityKey)
        let cleaner = Cleaner(defaults)
        let updates = Updates(defaults)
        cleaner.scheduleNext()
        updates.scheduleNext()
        suite.expect(cleaner.scheduled.isEmpty && updates.timer == nil && updates.nextCheck == nil,
                     "queued wake callbacks cannot arm a disabled Cleaner or App Updates schedule")
        defaults.set(true, forKey: AppFeature.cleaner.availabilityKey)
        defaults.set(true, forKey: AppFeature.appUpdates.availabilityKey)
        cleaner.scheduleNext()
        updates.scheduleNext()
        suite.expect(cleaner.scheduled.count == 1 && updates.timer != nil && updates.nextCheck != nil,
                     "enabled scheduled utilities can rearm after waking")
        updates.timer?.invalidate()
        updates.timer = nil
        updates.nextCheck = nil
        defaults.set(false, forKey: AppFeature.cleaner.availabilityKey)
        defaults.set(false, forKey: AppFeature.appUpdates.availabilityKey)
        cleaner.scheduleNext()
        updates.scheduleNext()
        suite.expect(cleaner.scheduled.count == 1 && updates.timer == nil,
                     "a callback already queued before disable cannot recreate either schedule")
    }
}
