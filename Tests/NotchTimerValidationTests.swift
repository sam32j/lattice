import Foundation

enum NotchTimerValidationTests {
    static func run(_ suite: TestSuite) {
        configurationDecode(suite)
        snapshotBounds(suite)
        toneLayout(suite)
    }

    private static func configurationDecode(_ suite: TestSuite) {
        let data = Data(#"{"focusMinutes":-5,"shortBreakMinutes":999,"longBreakMinutes":0,"longBreakInterval":0,"totalSessions":99}"#.utf8)
        guard let decoded = try? JSONDecoder().decode(NotchPomodoroConfiguration.self, from: data) else {
            suite.expect(false, "configuration with numeric fields remains decodable")
            return
        }
        suite.expect(decoded.focusMinutes == 1 && decoded.shortBreakMinutes == 60
            && decoded.longBreakMinutes == 1 && decoded.longBreakInterval == 1 && decoded.totalSessions == 24,
            "decoded Pomodoro configuration enforces the same bounds as user-created configuration")
    }
    private static func snapshotBounds(_ suite: TestSuite) {
        let clock = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func snapshot(mode: NotchTimerMode = .timer, phase: NotchTimerPhase = .timer,
                      duration: Double = 300, remaining: Double = 300, paused: Bool = false,
                      reading: Double? = nil, completed: Bool = false, focuses: Int = 0) -> NotchTimerCacheSnapshot {
            NotchTimerCacheSnapshot(mode: mode, phase: phase, duration: duration,
                targetEndDate: paused || completed || mode == .stopwatch ? nil : clock.addingTimeInterval(remaining),
                startDate: mode == .stopwatch && !paused ? clock.addingTimeInterval(-30) : nil,
                isPaused: paused, pausedReading: reading, completed: completed, completedFocuses: focuses,
                configuration: NotchPomodoroConfiguration(), savedAt: clock)
        }
        let invalid: [(String, NotchTimerCacheSnapshot)] = [
            ("negative duration", snapshot(duration: -1)),
            ("oversized duration", snapshot(duration: NotchTimerSupport.timerLimit + 1)),
            ("nonfinite duration", snapshot(duration: .infinity)),
            ("inconsistent timer phase", snapshot(phase: .focus)),
            ("inconsistent Pomodoro phase", snapshot(mode: .pomodoro)),
            ("oversized paused countdown", snapshot(paused: true, reading: 301)),
            ("oversized paused stopwatch", snapshot(mode: .stopwatch, phase: .stopwatch, duration: 0,
                                                    paused: true, reading: NotchTimerSupport.stopwatchLimit + 1)),
            ("future deadline beyond duration", snapshot(remaining: 100_000)),
            ("oversized completion count", snapshot(mode: .pomodoro, phase: .focus, focuses: Int.max)),
            ("paused and completed", snapshot(paused: true, reading: 90, completed: true)),
            ("stopwatch with countdown duration", snapshot(mode: .stopwatch, phase: .stopwatch, duration: 30))
        ]
        for (reason, value) in invalid {
            suite.expect(NotchTimerCache.restoreSession(from: value, now: 100, clockNow: clock) == nil,
                         "invalid cached timer is rejected: \(reason)")
        }
        suite.expect(NotchTimerCache.restoreSession(from: snapshot(), now: 100, clockNow: clock)?.reading(at: 100) == 300,
                     "a bounded running timer still restores")
        suite.expect(NotchTimerCache.restoreSession(from: snapshot(paused: true, reading: 90), now: 100, clockNow: clock)?.pausedReading == 90,
                     "a bounded paused timer still restores")
    }

    private static func toneLayout(_ suite: TestSuite) {
        func source(frames: Int = 24_000) -> Data {
            var data = Data(repeating: 0, count: 54 + frames * 6)
            func tag(_ text: String, _ index: Int) { data.replaceSubrange(index..<(index + 4), with: text.utf8) }
            func word(_ value: Int, _ index: Int) {
                for offset in 0..<4 { data[index + offset] = UInt8(truncatingIfNeeded: value >> ((3 - offset) * 8)) }
            }
            tag("FORM", 0); word(data.count - 8, 4); tag("AIFF", 8)
            tag("COMM", 12); word(18, 16); data[21] = 2; word(frames, 22); data[27] = 24
            tag("SSND", 38); word(frames * 6 + 8, 42)
            return data
        }
        let valid = source()
        for rate in [Double.nan, .infinity, -1, 0, 1_000_000] {
            suite.expect(NotchTimerToneData.make(from: valid, sampleRate: rate) == nil,
                         "an invalid requested sample rate fails before numeric conversion")
        }
        suite.expect(NotchTimerToneData.make(from: valid, sampleRate: 48_000)?.count == 86_454,
                     "validated PCM tone keeps exactly 300ms of stereo 24-bit audio")
        for (offset, value) in [(8, UInt8(0)), (19, 19), (21, 1), (27, 16), (38, 0), (49, 1)] {
            var broken = valid; broken[offset] = value
            suite.expect(NotchTimerToneData.make(from: broken, sampleRate: 48_000) == nil,
                         "an incompatible AIFF layout cannot be patched at hard-coded offsets: \(offset)")
        }
        let high = 48_000.0 * pow(2, 7.0 / 12.0)
        suite.expect(NotchTimerToneData.make(from: source(frames: 14_400), sampleRate: high) == nil,
                     "insufficient source frames fail instead of returning an unpitched full-length sound")
    }

}
