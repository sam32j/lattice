// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchTimerCacheSnapshot: Codable, Equatable {
    let mode: NotchTimerMode
    let phase: NotchTimerPhase
    let duration: TimeInterval
    let targetEndDate: Date?
    let startDate: Date?
    let isPaused: Bool
    let pausedReading: TimeInterval?
    let completed: Bool
    let completedFocuses: Int
    let configuration: NotchPomodoroConfiguration
    let savedAt: Date
}

enum NotchTimerCache {
    static let maxGracePeriod: TimeInterval = 5 * 60
    static let maxStopwatchElapsed: TimeInterval = 24 * 60 * 60

    static var defaultFolderURL: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.sam32j.lattice"
        return caches.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Timer", isDirectory: true)
    }

    static var defaultFileURL: URL? {
        defaultFolderURL?.appendingPathComponent("session.json", isDirectory: false)
    }

    static func save(_ snapshot: NotchTimerCacheSnapshot, to url: URL? = defaultFileURL) {
        guard let url else { return }
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {}
    }

    static func load(from url: URL? = defaultFileURL) -> NotchTimerCacheSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(NotchTimerCacheSnapshot.self, from: data)
    }

    static func delete(at url: URL? = defaultFileURL) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func createSnapshot(from session: NotchTimerSession, now: TimeInterval, clockNow: Date = Date()) -> NotchTimerCacheSnapshot? {
        guard session.hasSession else { return nil }
        let reading = session.reading(at: now)
        let targetEndDate: Date?
        let startDate: Date?
        let pausedReading: TimeInterval?

        if session.completed {
            targetEndDate = nil
            startDate = nil
            pausedReading = nil
        } else if session.isPaused {
            targetEndDate = nil
            startDate = nil
            pausedReading = reading
        } else if session.countsUp {
            targetEndDate = nil
            startDate = clockNow.addingTimeInterval(-reading)
            pausedReading = nil
        } else {
            targetEndDate = clockNow.addingTimeInterval(reading)
            startDate = nil
            pausedReading = nil
        }

        return NotchTimerCacheSnapshot(
            mode: session.mode,
            phase: session.phase,
            duration: session.duration,
            targetEndDate: targetEndDate,
            startDate: startDate,
            isPaused: session.isPaused,
            pausedReading: pausedReading,
            completed: session.completed,
            completedFocuses: session.completedFocuses,
            configuration: session.configuration,
            savedAt: clockNow
        )
    }

    static func restoreSession(from snapshot: NotchTimerCacheSnapshot,
                               now: TimeInterval,
                               clockNow: Date = Date(),
                               gracePeriod: TimeInterval = maxGracePeriod) -> NotchTimerSession? {
        if snapshot.completed {
            let age = clockNow.timeIntervalSince(snapshot.savedAt)
            guard age >= 0, age <= gracePeriod else { return nil }
            return NotchTimerSession(
                mode: snapshot.mode,
                phase: snapshot.phase,
                duration: snapshot.duration,
                anchor: nil,
                pausedReading: nil,
                completed: true,
                completedFocuses: snapshot.completedFocuses,
                configuration: snapshot.configuration
            )
        }

        if snapshot.isPaused {
            guard let reading = snapshot.pausedReading, reading >= 0 else { return nil }
            return NotchTimerSession(
                mode: snapshot.mode,
                phase: snapshot.phase,
                duration: snapshot.duration,
                anchor: nil,
                pausedReading: reading,
                completed: false,
                completedFocuses: snapshot.completedFocuses,
                configuration: snapshot.configuration
            )
        }

        if snapshot.mode == .stopwatch {
            guard let startDate = snapshot.startDate else { return nil }
            let elapsed = clockNow.timeIntervalSince(startDate)
            guard elapsed >= 0, elapsed <= maxStopwatchElapsed else { return nil }
            return NotchTimerSession(
                mode: .stopwatch,
                phase: .stopwatch,
                duration: 0,
                anchor: now - elapsed,
                pausedReading: nil,
                completed: false,
                completedFocuses: 0,
                configuration: snapshot.configuration
            )
        }

        if let targetEndDate = snapshot.targetEndDate {
            let remaining = targetEndDate.timeIntervalSince(clockNow)
            if remaining > 0 {
                return NotchTimerSession(
                    mode: snapshot.mode,
                    phase: snapshot.phase,
                    duration: snapshot.duration,
                    anchor: now + remaining,
                    pausedReading: nil,
                    completed: false,
                    completedFocuses: snapshot.completedFocuses,
                    configuration: snapshot.configuration
                )
            } else {
                let overdue = -remaining
                guard overdue <= gracePeriod else { return nil }
                return NotchTimerSession(
                    mode: snapshot.mode,
                    phase: snapshot.phase,
                    duration: snapshot.duration,
                    anchor: nil,
                    pausedReading: nil,
                    completed: true,
                    completedFocuses: snapshot.completedFocuses + (snapshot.phase == .focus ? 1 : 0),
                    configuration: snapshot.configuration
                )
            }
        }

        return nil
    }
}
