// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Lattice

import AppKit
import CoreGraphics
import Foundation

enum NotchTimerMode: String, CaseIterable, Codable {
    case stopwatch, timer, pomodoro
}

enum NotchTimerPhase: String, Codable {
    case timer, focus, shortBreak, longBreak, stopwatch
}

// MARK: - Ruler

enum NotchTimerRulerScale {
    static let spacing = 14.0

    static func moving(_ value: Double, by points: Double) -> Double {
        guard value.isFinite, points.isFinite else { return 1 }
        return min(180, max(1, value - points / spacing))
    }

    static func minute(_ value: Double) -> Int {
        Int(moving(value, by: 0).rounded())
    }

    static func offset(of minute: Int, selected: Int) -> Double {
        (Double(minute) - Double(selected)) * spacing
    }

    static func label(for minute: Int) -> String {
        minute >= 60
            ? NotchTimerSupport.hoursText(
                hours: minute / 60,
                minutes: minute % 60
            )
            : String(minute)
    }
}

// MARK: - Pomodoro configuration

/// Preferences describe the next cycle.
/// A running cycle retains its own configuration snapshot.
struct NotchPomodoroConfiguration: Equatable, Codable {
    static let focusRange = 5...90
    static let breakRange = 3...30
    static let sessionRange = 2...8

    static let shortBreakChoices = [3, 5, 10]
    static let longBreakChoices = [10, 15, 20, 30]
    static let totalSessionChoices = [2, 3, 4, 5, 6, 8]

    let focusMinutes: Int
    let shortBreakMinutes: Int
    let longBreakMinutes: Int
    let longBreakInterval: Int
    let totalSessions: Int

    static func longBreakIntervalChoices(
        totalSessions: Int
    ) -> [Int] {
        guard totalSessions > 2 else { return [0] }
        return [0] + Array(2..<totalSessions)
    }

    /// Closest supported preset, retaining sensible values when
    /// migrating preferences from the old continuous ranges.
    private static func nearest(
        _ value: Int,
        in choices: [Int]
    ) -> Int {
        choices.min { a, b in
            let left = abs(Double(a) - Double(value))
            let right = abs(Double(b) - Double(value))
            return left == right ? a < b : left < right
        } ?? value
    }

    init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        longBreakInterval: Int = 2,
        totalSessions: Int = 4
    ) {
        let total = Self.nearest(
            totalSessions,
            in: Self.totalSessionChoices
        )

        self.totalSessions = total
        self.focusMinutes = min(
            Self.focusRange.upperBound,
            max(Self.focusRange.lowerBound, focusMinutes)
        )
        self.shortBreakMinutes = Self.nearest(
            shortBreakMinutes,
            in: Self.shortBreakChoices
        )
        self.longBreakMinutes = Self.nearest(
            longBreakMinutes,
            in: Self.longBreakChoices
        )

        // Zero means no long break. An interval must leave at
        // least one future focus session after the long break.
        self.longBreakInterval =
            Self.longBreakIntervalChoices(totalSessions: total)
                .contains(longBreakInterval)
            ? longBreakInterval
            : 0
    }

    static func load(
        in defaults: UserDefaults = .standard
    ) -> Self {
        Self(
            focusMinutes: defaults.object(
                forKey: DefaultsKey.notchPomodoroFocusMinutes
            ) as? Int ?? 25,
            shortBreakMinutes: defaults.object(
                forKey: DefaultsKey.notchPomodoroShortBreakMinutes
            ) as? Int ?? 5,
            longBreakMinutes: defaults.object(
                forKey: DefaultsKey.notchPomodoroLongBreakMinutes
            ) as? Int ?? 15,
            longBreakInterval: defaults.object(
                forKey: DefaultsKey.notchPomodoroLongBreakInterval
            ) as? Int ?? 2,
            totalSessions: defaults.object(
                forKey: DefaultsKey.notchPomodoroTotalSessions
            ) as? Int ?? 4
        )
    }
}

// MARK: - Pomodoro settings options

enum NotchPomodoroOption: CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak
    case longBreakInterval
    case totalSessions

    var id: Self { self }

    /// Retained for compatibility with existing readout code.
    /// New settings menus should use choices(totalSessions:).
    var range: ClosedRange<Int> {
        switch self {
        case .focus:
            return NotchPomodoroConfiguration.focusRange
        case .shortBreak:
            return 3...10
        case .longBreak:
            return 10...30
        case .longBreakInterval:
            return 0...7
        case .totalSessions:
            return NotchPomodoroConfiguration.sessionRange
        }
    }

    func choices(totalSessions: Int = 4) -> [Int] {
        switch self {
        case .focus:
            return Array(NotchPomodoroConfiguration.focusRange)
        case .shortBreak:
            return NotchPomodoroConfiguration.shortBreakChoices
        case .longBreak:
            return NotchPomodoroConfiguration.longBreakChoices
        case .longBreakInterval:
            return NotchPomodoroConfiguration
                .longBreakIntervalChoices(totalSessions: totalSessions)
        case .totalSessions:
            return NotchPomodoroConfiguration.totalSessionChoices
        }
    }

    var isDuration: Bool {
        switch self {
        case .focus, .shortBreak, .longBreak:
            return true
        case .longBreakInterval, .totalSessions:
            return false
        }
    }
}

// MARK: - Session state

/// The anchor is an injected monotonic time coordinate:
/// a countdown deadline or the instant a stopwatch read zero.
///
/// UI refreshes never subtract ticks, so sleep and delayed
/// callbacks cannot introduce accumulated drift.
struct NotchTimerSession: Equatable {
    var mode: NotchTimerMode = .timer
    var phase: NotchTimerPhase = .timer
    var duration: TimeInterval = 300
    var anchor: TimeInterval?
    var pausedReading: TimeInterval?
    var completed = false
    var completedFocuses = 0
    var configuration = NotchPomodoroConfiguration()

    var countsUp: Bool { mode == .stopwatch }
    var isRunning: Bool { anchor != nil }
    var isPaused: Bool { pausedReading != nil }
    var hasSession: Bool { isRunning || isPaused || completed }
    var deadline: TimeInterval? { countsUp ? nil : anchor }

    var cycleFinished: Bool {
        mode == .pomodoro
            && completed
            && completedFocuses >= configuration.totalSessions
    }

    var canStartNext: Bool {
        mode == .pomodoro && completed && !cycleFinished
    }

    var sessionNumber: Int {
        min(
            configuration.totalSessions,
            completedFocuses
                + (phase == .focus && !completed ? 1 : 0)
        )
    }

    /// Seconds left for countdowns, elapsed for Stopwatch.
    func reading(at now: TimeInterval) -> TimeInterval {
        if let anchor {
            return max(
                0,
                countsUp ? now - anchor : anchor - now
            )
        }

        return pausedReading
            ?? (completed || countsUp ? 0 : duration)
    }

    mutating func start(
        mode: NotchTimerMode,
        minutes: Int,
        now: TimeInterval,
        configuration: NotchPomodoroConfiguration =
            NotchPomodoroConfiguration()
    ) {
        guard !hasSession, now.isFinite else { return }

        self.mode = mode
        self.configuration = configuration
        completedFocuses = 0
        completed = false
        pausedReading = nil

        switch mode {
        case .timer:
            phase = .timer
            duration = Double(
                NotchTimerSupport.timerMinutes(minutes)
            ) * 60
            anchor = now + duration

        case .pomodoro:
            phase = .focus
            duration = Double(configuration.focusMinutes) * 60
            anchor = now + duration

        case .stopwatch:
            phase = .stopwatch
            duration = 0
            anchor = now
        }
    }

    @discardableResult
    mutating func finishIfDue(at now: TimeInterval) -> Bool {
        guard let deadline,
            now.isFinite,
            now >= deadline else {
            return false
        }

        anchor = nil
        pausedReading = nil
        completed = true

        if phase == .focus {
            completedFocuses += 1
        }

        return true
    }

    mutating func pause(at now: TimeInterval) {
        guard isRunning, now.isFinite else { return }
        if finishIfDue(at: now) { return }

        pausedReading = reading(at: now)
        anchor = nil
    }

    mutating func resume(at now: TimeInterval) {
        guard let reading = pausedReading,
            now.isFinite else {
            return
        }

        pausedReading = nil
        anchor = countsUp
            ? now - reading
            : now + reading
    }

    /// The phase following a completed focus or break.
    ///
    /// When interval is zero, only short breaks occur.
    /// The final focus never advances to another phase.
    var nextPhase: NotchTimerPhase {
        guard phase == .focus else {
            return .focus
        }

        let interval = configuration.longBreakInterval

        if interval >= 2,
        interval < configuration.totalSessions,
        completedFocuses > 0,
        completedFocuses < configuration.totalSessions,
        completedFocuses.isMultiple(of: interval) {
            return .longBreak
        }

        return .shortBreak
    }

    /// Advances one phase from the current time.
    ///
    /// NotchTimerService now invokes this automatically.
    /// A delayed wake never simulates missed cycles.
    mutating func startNext(at now: TimeInterval) {
        guard canStartNext, now.isFinite else { return }

        phase = nextPhase

        switch phase {
        case .focus:
            duration = Double(configuration.focusMinutes) * 60
        case .shortBreak:
            duration = Double(configuration.shortBreakMinutes) * 60
        case .longBreak:
            duration = Double(configuration.longBreakMinutes) * 60
        case .timer, .stopwatch:
            return
        }

        completed = false
        pausedReading = nil
        anchor = now + duration
    }

    mutating func cancel() {
        self = Self()
    }
}

// MARK: - Support

enum NotchTimerSupport {

    /// Hiding the countdown never disables the session
    /// or its completion alerts.
    static func showsActivity(
        _ session: NotchTimerSession,
        in defaults: UserDefaults = .standard
    ) -> Bool {
        session.hasSession
            && isEnabled(in: defaults)
            && (
                session.completed
                || !defaults.bool(
                    forKey: DefaultsKey.notchHideTimerCountdown
                )
            )
    }

    static func isSoundEnabled(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.object(
            forKey: DefaultsKey.notchTimerSoundEnabled
        ) as? Bool ?? true
    }

    static func isEnabled(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        NotchSupport.isEnabled(in: defaults)
            && AppFeature.notchTimer.isAvailable(in: defaults)
            && defaults.bool(
                forKey: DefaultsKey.notchTimerEnabled
            )
            && NotchSupport.modules(in: defaults).contains(.timer)
    }

    // MARK: Mode picker compatibility

    enum ModePicker {
        static let height: CGFloat = 24
        static let spacing: CGFloat = 14
        static let labelSize: CGFloat = 12
        static let labelPadding: CGFloat = 4
        static let menuSpacing: CGFloat = 3
        static let menuMinimumScale: CGFloat = 0.7

        static func menuNamesFit(
            _ names: [String],
            in room: CGFloat
        ) -> Bool {
            let font = NSFont.systemFont(
                ofSize: labelSize,
                weight: .medium
            )

            let widest = names.map {
                ($0 as NSString).size(
                    withAttributes: [.font: font]
                ).width
            }.max() ?? 0

            let chevron = NSImage(
                systemSymbolName: "chevron.down",
                accessibilityDescription: nil
            )?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: 9,
                    weight: .semibold
                )
            )?.size.width ?? 8

            return widest * menuMinimumScale * 1.05
                + menuSpacing
                + chevron
                + labelPadding * 2 <= room
        }

        static func symbol(for mode: NotchTimerMode) -> String {
            switch mode {
            case .stopwatch:
                return "stopwatch"
            case .timer:
                return "timer"
            case .pomodoro:
                return "tachometer"
            }
        }
    }

    enum StartButton {
        static let labelSize: CGFloat = 12
        static let padding: CGFloat = 10
    }

    // MARK: Time formatting

    static let timerLimit: TimeInterval = 180 * 60
    static let stopwatchLimit: TimeInterval = 100 * 3600 - 1

    static func timerMinutes(_ value: Int) -> Int {
        min(180, max(1, value))
    }

    static func savedMode(
        in defaults: UserDefaults = .standard
    ) -> NotchTimerMode {
        NotchTimerMode(
            rawValue: defaults.string(
                forKey: DefaultsKey.notchTimerMode
            ) ?? ""
        ) ?? .timer
    }

    private static func wholeSeconds(
        _ value: TimeInterval,
        limit: TimeInterval,
        rounded rule: FloatingPointRoundingRule
    ) -> Int {
        value.isFinite
            ? Int(min(limit, max(0, value)).rounded(rule))
            : 0
    }

    private static func clockText(seconds: Int) -> String {
        if seconds >= 3600 {
            return String(
                format: "%d:%02d:%02d",
                seconds / 3600,
                seconds / 60 % 60,
                seconds % 60
            )
        }

        return String(
            format: "%02d:%02d",
            seconds / 60,
            seconds % 60
        )
    }

    static func clockText(_ remaining: TimeInterval) -> String {
        clockText(
            seconds: wholeSeconds(
                remaining,
                limit: timerLimit,
                rounded: .up
            )
        )
    }

    /// Stopwatch never rounds up to a second it has not reached.
    ///
    /// Existing callers retain whole-second formatting.
    /// Set includesMilliseconds for expanded displays.
    static func stopwatchText(
        _ elapsed: TimeInterval,
        includesMilliseconds: Bool = false
    ) -> String {
        guard includesMilliseconds else {
            return clockText(
                seconds: wholeSeconds(
                    elapsed,
                    limit: stopwatchLimit,
                    rounded: .down
                )
            )
        }

        let bounded = elapsed.isFinite
            ? min(stopwatchLimit + 0.999, max(0, elapsed))
            : 0

        let milliseconds = Int((bounded * 1000).rounded(.down))
        let seconds = milliseconds / 1000
        let fraction = milliseconds % 1000

        return String(
            format: "%@.%03d",
            clockText(seconds: seconds),
            fraction
        )
    }

    /// Hours read as "1h35", never "1:35", which beside
    /// a minute clock would look like one minute, 35 seconds.
    static func hoursText(
        hours: Int,
        minutes: Int
    ) -> String {
        String(format: "%dh%02d", hours, minutes)
    }

    static func compactHoursText(
        _ remaining: TimeInterval
    ) -> String {
        let seconds = wholeSeconds(
            remaining,
            limit: timerLimit,
            rounded: .down
        )

        return hoursText(
            hours: seconds / 3600,
            minutes: seconds / 60 % 60
        )
    }

    /// Compact Stopwatch may show milliseconds when the wing
    /// has room. The default keeps the original short reading.
    static func compactStopwatchText(
        _ elapsed: TimeInterval,
        showMilliseconds: Bool = false
    ) -> String {
        if showMilliseconds {
            return stopwatchText(
                elapsed,
                includesMilliseconds: true
            )
        }

        let seconds = wholeSeconds(
            elapsed,
            limit: stopwatchLimit,
            rounded: .down
        )

        return seconds >= 3600
            ? hoursText(
                hours: seconds / 3600,
                minutes: seconds / 60 % 60
            )
            : clockText(seconds: seconds)
    }

    static func clockText(
        for session: NotchTimerSession,
        at now: TimeInterval,
        includesMilliseconds: Bool = false
    ) -> String {
        let reading = session.reading(at: now)

        return session.countsUp
            ? stopwatchText(
                reading,
                includesMilliseconds: includesMilliseconds
            )
            : clockText(reading)
    }

    /// The closed island can roll leading digits while seconds
    /// change in place, minimizing animation and energy use.
    static func rollingValue(
        _ value: String,
        everySecond: Bool
    ) -> String {
        guard !everySecond,
            let colon = value.lastIndex(of: ":") else {
            return value
        }

        return String(value[..<colon])
    }

    
    static func compactText(
        for session: NotchTimerSession,
        at now: TimeInterval,
        locale: Locale,
        showMilliseconds: Bool = false
    ) -> String {
        if session.cycleFinished {
            return "Completed"
        }
        let reading = session.reading(at: now)

        switch session.mode {
        case .timer where session.completed:
            return FeatureStrings.notchActivities(
                L10n.shared.language
            ).finished

        case .stopwatch:
            return compactStopwatchText(
                reading,
                showMilliseconds: showMilliseconds
            )

        case .timer, .pomodoro:
            return reading >= 3600
                ? compactHoursText(reading)
                : compactText(reading, locale: locale)
        }
    }


    /// Seconds until the next whole-second boundary.
    static func secondBoundaryOffset(
        for session: NotchTimerSession,
        at now: TimeInterval
    ) -> TimeInterval {
        let reading = session.reading(at: now)

        guard reading.isFinite else { return 0 }

        let fraction = reading.truncatingRemainder(
            dividingBy: 1
        )

        let offset = session.countsUp
            ? 1 - fraction
            : fraction

        return offset > 0 ? offset : 1
    }

    static func tickScheduleOffset(
        for session: NotchTimerSession,
        at now: TimeInterval
    ) -> TimeInterval {
        secondBoundaryOffset(
            for: session,
            at: now
        ) - 1
    }

    static func compactText(
        _ remaining: TimeInterval,
        locale: Locale
    ) -> String {
        let seconds = remaining.isFinite
            ? ceil(min(timerLimit, max(0, remaining)))
            : 0

        let units: Set<Duration.UnitsFormatStyle.Unit> =
            seconds >= 3600
            ? [.hours, .minutes]
            : [seconds >= 60 ? .minutes : .seconds]

        return Duration.seconds(seconds).formatted(
            .units(
                allowed: units,
                width: .narrow,
                fractionalPart: .hide(rounded: .down)
            ).locale(locale)
        )
    }

    // MARK: Compact strip

    static let stripWingRange: ClosedRange<CGFloat> = 44...90
    static let stripCameraGap: CGFloat = 6

    static func stripTextSize(height: CGFloat) -> CGFloat {
        min(16, height - 6)
    }

    static func stripIconSize(height: CGFloat) -> CGFloat {
        min(
            20,
            height - NotchLayout.compactEdgeGap * 2
        )
    }

    static func stripAgentMarkSize(
        height: CGFloat,
        working: Int
    ) -> CGFloat {
        min(
            working > 1 ? 11 : 14,
            max(
                8,
                height - NotchLayout.compactEdgeGap * 2 - 4
            )
        )
    }
}
