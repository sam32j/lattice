import Foundation

enum HubStayAwakeContract {
    class State {
        var isActive = false
        var endDate: Date?
        var sessionMinutes: Int?
        var events: [String] = []
        func activate(minutes: Int) { events.append("start:\(minutes)") }
        func extend(minutes: Int) { events.append("extend:\(minutes)") }
        func toggle() { events.append("stop") }
        func syncWithPreferences() { events.append("reconcile") }
    }
}

enum HubStayAwakeTests {
    static func run(_ suite: TestSuite) {
        let state = HubStayAwakeContract.Service()
        state.reconcileHubSession()
        suite.expect(state.events.isEmpty, "opening options does not activate an inactive session")
        state.toggleFromHub()
        suite.expect(state.events == ["start:60"], "the Hub bolt starts exactly one hour")
        state.isActive = true
        state.toggleFromHub()
        suite.expect(state.events.last == "stop", "the Hub bolt stops any active session")
        state.endDate = Date().addingTimeInterval(3600)
        state.sessionMinutes = 60
        state.addHubDuration(minutes: 15)
        suite.expect(state.events.last == "extend:15", "timed sessions extend through the manager")
        state.sessionMinutes = nil
        state.addHubDuration(minutes: 15)
        suite.expect(state.events.last == "start:15", "until-time sessions switch to a fresh timed session")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let end = now.addingTimeInterval(42 * 60)
        suite.expect(HubStayAwakeSupport.durationEnd(minutes: 15, isTimed: true, end: end, now: now)
            == now.addingTimeInterval(57 * 60), "duration adds to the actual expiration")
        suite.expect(HubStayAwakeSupport.durationEnd(minutes: 60, isTimed: false, end: end, now: now)
            == now.addingTimeInterval(3600), "until-time mode is replaced with a new timed session")
        suite.expect(HubStayAwakeSupport.durationEnd(minutes: 15, isTimed: false, end: nil, now: now)
            == now.addingTimeInterval(900), "indefinite or inactive starts a fresh duration")
        suite.expect(HubStayAwakeSupport.compact(end: now.addingTimeInterval(3600), now: now) == "60′",
                     "short sessions use whole minutes beside the bolt")
        suite.expect(HubStayAwakeSupport.compact(end: now.addingTimeInterval(1), now: now) == "1′",
                     "the last minute stays visible")
        suite.expect(HubStayAwakeSupport.compact(end: nil, now: now) == "∞", "indefinite has an infinity reading")
        for (minutes, expected) in [(179.99, "180′"), (180.0, "180′"), (180.001, "3hr"),
                                    (187.49, "3hr"), (187.5, "3¼hr"), (195.0, "3¼hr"), (202.5, "3½hr"),
                                    (998.0, "16¾hr"), (998.99, "16¾hr"), (999.0, "16¾hr"),
                                    (1012.49, "16¾hr"), (1012.5, "17hr"), (1035.0, "17¼hr"),
                                    (1050.0, "17½hr"), (1065.0, "17¾hr"), (1072.5, "18hr")] {
            suite.expect(HubStayAwakeSupport.compact(end: now.addingTimeInterval(minutes * 60), now: now) == expected,
                         "compact remaining time rounds quarter hours and carries across the hour: \(minutes)")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 18))!
        let earlier = calendar.date(bySettingHour: 17, minute: 30, second: 0, of: today)!
        let next = HubStayAwakeSupport.nextOccurrence(of: earlier, now: today, calendar: calendar)
        suite.expect(calendar.component(.day, from: next) == 31 && calendar.component(.hour, from: next) == 17,
                     "a time that passed today means tomorrow")
        let later = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today)!
        suite.expect(HubStayAwakeSupport.nextOccurrence(of: later, now: today, calendar: calendar) == later,
                     "an upcoming time stays today")
    }
}
