import Foundation

enum NotchTimerAnnouncementContract {
    enum Support {
        static func isEnabled() -> Bool { true }
        static func isSoundEnabled() -> Bool { false }
    }
    enum UI {
        static let shared = Host()
        enum Reaction { case ready }
        final class Host {
            func endMascotCountdown(retreating: Bool) {}
            func reactMascot(_ reaction: Reaction) {}
        }
    }
    final class Alert {
        func stop() {}
        func suspend() {}
        func start(enabled: Bool) {}
    }
    enum Cache {
        static let file = FileManager.default.temporaryDirectory.appendingPathComponent("lattice-timer-once-\(UUID()).json")
        static let clock = Date(timeIntervalSinceReferenceDate: 800_000_000)
        static func load() -> NotchTimerCacheSnapshot? { NotchTimerCache.load(from: file) }
        static func save(_ snapshot: NotchTimerCacheSnapshot) { NotchTimerCache.save(snapshot, to: file) }
        static func delete() { NotchTimerCache.delete(at: file) }
        static func createSnapshot(from session: NotchTimerSession, now: TimeInterval) -> NotchTimerCacheSnapshot? {
            NotchTimerCache.createSnapshot(from: session, now: now, clockNow: clock)
        }
        static func restoreSession(from snapshot: NotchTimerCacheSnapshot, now: TimeInterval) -> NotchTimerSession? {
            NotchTimerCache.restoreSession(from: snapshot, now: now, clockNow: clock)
        }
    }
}

enum NotchTimerAnnouncementTests {
    static func run(_ suite: TestSuite) {
        typealias C = NotchTimerAnnouncementContract
        C.Cache.delete()
        defer { C.Cache.delete() }
        var completed = NotchTimerSession()
        completed.start(mode: .timer, minutes: 1, now: 0)
        completed.finishIfDue(at: 60)
        C.Cache.save(C.Cache.createSnapshot(from: completed, now: 60)!)
        let first = C.Service()
        first.syncWithPreferences()
        suite.expect(first.announcements == 1 && first.session.completed && C.Cache.load() == nil,
                     "restoring a recent completed timer announces it once and consumes its snapshot")
        first.suspend()
        suite.expect(C.Cache.load() == nil, "suspending an announced completion never recreates its snapshot")
        let second = C.Service()
        second.syncWithPreferences()
        suite.expect(second.announcements == 0 && !second.session.hasSession,
                     "another launch cannot announce the same completed timer again")
        let overdue = NotchTimerCacheSnapshot(mode: .timer, phase: .timer, duration: 60,
            targetEndDate: C.Cache.clock.addingTimeInterval(-10), startDate: nil, isPaused: false,
            pausedReading: nil, completed: false, completedFocuses: 0,
            configuration: NotchPomodoroConfiguration(), savedAt: C.Cache.clock)
        C.Cache.save(overdue)
        let expired = C.Service()
        expired.syncWithPreferences()
        expired.suspend()
        suite.expect(expired.announcements == 1 && expired.session.completed && C.Cache.load() == nil,
                     "a timer that expired while the app was closed is announced and consumed once")

        for mode in NotchTimerMode.allCases {
            for paused in [false, true] {
                C.Cache.delete()
                var original = NotchTimerSession()
                original.start(mode: mode, minutes: 5, now: 0)
                if paused { original.pause(at: 30) }
                C.Cache.save(C.Cache.createSnapshot(from: original, now: 30)!)
                let restored = C.Service()
                restored.syncWithPreferences()
                suite.expect(restored.session.mode == mode && restored.session.isPaused == paused
                             && restored.session.reading(at: restored.now) == original.reading(at: 30)
                             && restored.announcements == 0 && C.Cache.load() != nil,
                             "incomplete sessions retain their mode, reading and cache: \(mode), paused \(paused)")
                restored.suspend()
                let relaunched = C.Service()
                relaunched.syncWithPreferences()
                suite.expect(relaunched.session == restored.session && relaunched.announcements == 0,
                             "suspension preserves incomplete restoration: \(mode), paused \(paused)")
            }
        }
        C.Cache.delete()
        let live = C.Service()
        live.session.start(mode: .timer, minutes: 1, now: live.now)
        C.Cache.save(C.Cache.createSnapshot(from: live.session, now: live.now)!)
        live.now += 61
        live.syncWithPreferences()
        live.syncWithPreferences()
        live.suspend()
        suite.expect(live.session.completed && live.announcements == 1 && C.Cache.load() == nil,
                     "live completion is announced once and later preference sync or suspension cannot cache it again")

        var focus = NotchTimerSession()
        focus.start(mode: .pomodoro, minutes: 1, now: 0)
        focus.finishIfDue(at: focus.deadline!)
        C.Cache.save(C.Cache.createSnapshot(from: focus, now: 0)!)
        let pomodoro = C.Service()
        pomodoro.syncWithPreferences()
        pomodoro.startNext()
        suite.expect(pomodoro.announcements == 1 && pomodoro.session.phase == .shortBreak
                     && pomodoro.session.isRunning && !pomodoro.session.completed
                     && C.Cache.load()?.phase == .shortBreak,
                     "consuming a completion keeps the next Pomodoro phase available and cacheable")

    }
}
