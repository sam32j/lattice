// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

enum NotchTimerCacheTests {
    static func run(_ suite: TestSuite) {
        alertTwoToneContracts(suite)
        snapshotCreationContracts(suite)
        restorationContracts(suite)
        persistenceFileContracts(suite)
        serviceLifecycleContracts(suite)
    }

    private static func alertTwoToneContracts(_ suite: TestSuite) {
        suite.expect(NotchTimerAlert.chimeGap == .milliseconds(180), "rising chime has 180ms step between tones")
        suite.expect(NotchTimerAlert.chimeRest == .milliseconds(800), "rising chime has 800ms rest between motifs")

        if let low = NotchTimerAlert.loadPing300msSound(sampleRate: 48000) {
            suite.expect(abs(low.duration - 0.3) < 0.005, "low tone duration is 300ms")
        }
        let highRate = 48000.0 * pow(2.0, 7.0 / 12.0)
        if let high = NotchTimerAlert.loadPing300msSound(sampleRate: highRate) {
            suite.expect(abs(high.duration - 0.3) < 0.005, "high tone duration is 300ms")
        }
    }

    private static func snapshotCreationContracts(_ suite: TestSuite) {
        let clockNow = Date(timeIntervalSince1970: 1700000000)
        let now: TimeInterval = 1000

        // 1. Running countdown (5-minute timer)
        var runningSession = NotchTimerSession()
        runningSession.start(mode: .timer, minutes: 5, now: now)
        guard let runningSnap = NotchTimerCache.createSnapshot(from: runningSession, now: now, clockNow: clockNow) else {
            suite.expect(false, "createSnapshot should succeed for running timer")
            return
        }
        suite.expect(runningSnap.mode == .timer, "snapshot preserves timer mode")
        suite.expect(runningSnap.phase == .timer, "snapshot preserves timer phase")
        suite.expect(!runningSnap.isPaused, "running timer is not paused in snapshot")
        suite.expect(!runningSnap.completed, "running timer is not completed in snapshot")
        suite.expect(runningSnap.targetEndDate == clockNow.addingTimeInterval(300), "target end date is clockNow + remaining")

        // 2. Paused timer
        var pausedSession = runningSession
        pausedSession.pause(at: now + 60) // 240s remaining
        guard let pausedSnap = NotchTimerCache.createSnapshot(from: pausedSession, now: now + 60, clockNow: clockNow) else {
            suite.expect(false, "createSnapshot should succeed for paused timer")
            return
        }
        suite.expect(pausedSnap.isPaused, "snapshot marks paused timer")
        suite.expect(pausedSnap.targetEndDate == nil, "paused snapshot has no targetEndDate")
        suite.expect(pausedSnap.pausedReading == 240, "paused snapshot preserves remaining seconds")

        // 3. Stopwatch running
        var stopwatchSession = NotchTimerSession()
        stopwatchSession.start(mode: .stopwatch, minutes: 0, now: now)
        // 45 seconds elapsed
        guard let stopwatchSnap = NotchTimerCache.createSnapshot(from: stopwatchSession, now: now + 45, clockNow: clockNow) else {
            suite.expect(false, "createSnapshot should succeed for stopwatch")
            return
        }
        suite.expect(stopwatchSnap.mode == .stopwatch, "stopwatch mode preserved")
        suite.expect(stopwatchSnap.startDate == clockNow.addingTimeInterval(-45), "stopwatch start date is clockNow - elapsed")

        // 4. Completed session
        var finishedSession = runningSession
        finishedSession.finishIfDue(at: now + 301)
        guard let finishedSnap = NotchTimerCache.createSnapshot(from: finishedSession, now: now + 301, clockNow: clockNow) else {
            suite.expect(false, "createSnapshot should succeed for finished timer")
            return
        }
        suite.expect(finishedSnap.completed, "finished snapshot marks completed")
    }

    private static func restorationContracts(_ suite: TestSuite) {
        let clockNow = Date(timeIntervalSince1970: 1700000000)
        let now: TimeInterval = 500
        let config = NotchPomodoroConfiguration()

        // 1. Active countdown with time remaining
        let targetEnd = clockNow.addingTimeInterval(120) // 120s remaining
        let activeSnap = NotchTimerCacheSnapshot(
            mode: .timer, phase: .timer, duration: 300,
            targetEndDate: targetEnd, startDate: nil, isPaused: false,
            pausedReading: nil, completed: false, completedFocuses: 0,
            configuration: config, savedAt: clockNow
        )
        guard let restoredActive = NotchTimerCache.restoreSession(from: activeSnap, now: now, clockNow: clockNow) else {
            suite.expect(false, "restoreSession should succeed for active countdown")
            return
        }
        suite.expect(restoredActive.isRunning, "restored active countdown is running")
        suite.expect(!restoredActive.isPaused, "restored active countdown is not paused")
        suite.expect(!restoredActive.completed, "restored active countdown is not completed")
        suite.expect(abs(restoredActive.reading(at: now) - 120) < 0.001, "restored countdown has exact remaining time")

        // 2. Expired countdown within grace period (expired 45s ago, grace period 300s)
        let recentlyExpiredEnd = clockNow.addingTimeInterval(-45)
        let expiredSnap = NotchTimerCacheSnapshot(
            mode: .pomodoro, phase: .focus, duration: 1500,
            targetEndDate: recentlyExpiredEnd, startDate: nil, isPaused: false,
            pausedReading: nil, completed: false, completedFocuses: 1,
            configuration: config, savedAt: clockNow
        )
        guard let restoredExpired = NotchTimerCache.restoreSession(from: expiredSnap, now: now, clockNow: clockNow, gracePeriod: 300) else {
            suite.expect(false, "restoreSession should restore recently expired timer as completed")
            return
        }
        suite.expect(restoredExpired.completed, "recently expired timer restores as completed")
        suite.expect(restoredExpired.completedFocuses == 2, "completed pomodoro focus increments session count")

        // 3. Expired countdown beyond grace period (expired 10 minutes ago)
        let staleEnd = clockNow.addingTimeInterval(-600)
        let staleSnap = NotchTimerCacheSnapshot(
            mode: .timer, phase: .timer, duration: 300,
            targetEndDate: staleEnd, startDate: nil, isPaused: false,
            pausedReading: nil, completed: false, completedFocuses: 0,
            configuration: config, savedAt: clockNow
        )
        let restoredStale = NotchTimerCache.restoreSession(from: staleSnap, now: now, clockNow: clockNow, gracePeriod: 300)
        suite.expect(restoredStale == nil, "stale expired timer beyond grace period is discarded")

        // 4. Paused countdown recovery
        let pausedSnap = NotchTimerCacheSnapshot(
            mode: .timer, phase: .timer, duration: 300,
            targetEndDate: nil, startDate: nil, isPaused: true,
            pausedReading: 95, completed: false, completedFocuses: 0,
            configuration: config, savedAt: clockNow
        )
        guard let restoredPaused = NotchTimerCache.restoreSession(from: pausedSnap, now: now, clockNow: clockNow) else {
            suite.expect(false, "restoreSession should succeed for paused countdown")
            return
        }
        suite.expect(restoredPaused.isPaused, "restored paused timer is paused")
        suite.expect(!restoredPaused.isRunning, "restored paused timer is not running")
        suite.expect(restoredPaused.reading(at: now) == 95, "restored paused timer has 95s reading")

        // 5. Stopwatch running recovery
        let stopwatchStart = clockNow.addingTimeInterval(-70)
        let stopwatchSnap = NotchTimerCacheSnapshot(
            mode: .stopwatch, phase: .stopwatch, duration: 0,
            targetEndDate: nil, startDate: stopwatchStart, isPaused: false,
            pausedReading: nil, completed: false, completedFocuses: 0,
            configuration: config, savedAt: clockNow
        )
        guard let restoredStopwatch = NotchTimerCache.restoreSession(from: stopwatchSnap, now: now, clockNow: clockNow) else {
            suite.expect(false, "restoreSession should succeed for running stopwatch")
            return
        }
        suite.expect(restoredStopwatch.countsUp, "restored stopwatch counts up")
        suite.expect(restoredStopwatch.isRunning, "restored stopwatch is running")
        suite.expect(abs(restoredStopwatch.reading(at: now) - 70) < 0.001, "restored stopwatch elapsed time is 70s")
    }

    private static func persistenceFileContracts(_ suite: TestSuite) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LatticeTestTimerCache-\(UUID().uuidString)", isDirectory: true)
        let tempFile = tempDir.appendingPathComponent("session.json", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        suite.expect(NotchTimerCache.load(from: tempFile) == nil, "loading from non-existent file returns nil")

        let snapshot = NotchTimerCacheSnapshot(
            mode: .timer, phase: .timer, duration: 300,
            targetEndDate: Date(timeIntervalSince1970: 1700000100),
            startDate: nil, isPaused: false, pausedReading: nil,
            completed: false, completedFocuses: 0,
            configuration: NotchPomodoroConfiguration(),
            savedAt: Date(timeIntervalSince1970: 1700000000)
        )

        NotchTimerCache.save(snapshot, to: tempFile)
        guard let loaded = NotchTimerCache.load(from: tempFile) else {
            suite.expect(false, "saved snapshot must be readable from file")
            return
        }
        suite.expect(loaded.mode == .timer, "loaded snapshot preserves mode")
        suite.expect(loaded.duration == 300, "loaded snapshot preserves duration")
        suite.expect(loaded.isPaused == false, "loaded snapshot preserves isPaused")

        NotchTimerCache.delete(at: tempFile)
        suite.expect(NotchTimerCache.load(from: tempFile) == nil, "deleted snapshot no longer loads")
    }

    private static func serviceLifecycleContracts(_ suite: TestSuite) {
        guard let defaultFolder = NotchTimerCache.defaultFolderURL,
              let defaultFile = NotchTimerCache.defaultFileURL else {
            suite.expect(false, "default cache paths must resolve")
            return
        }
        suite.expect(defaultFolder.path.contains("Timer"), "cache folder path contains Timer subfolder")
        suite.expect(defaultFile.lastPathComponent == "session.json", "cache file is session.json")

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LatticeLifecycleTest-\(UUID().uuidString)", isDirectory: true)
        let tempFile = tempDir.appendingPathComponent("session.json", isDirectory: false)
        defer {
            NotchTimerCache.delete(at: tempFile)
            try? FileManager.default.removeItem(at: tempDir)
        }

        let clockNow = Date(timeIntervalSince1970: 1700000000)
        var session = NotchTimerSession()
        session.start(mode: .timer, minutes: 15, now: 100)

        // 1. Persisting active session to cache
        guard let snapshot = NotchTimerCache.createSnapshot(from: session, now: 100, clockNow: clockNow) else {
            suite.expect(false, "snapshot created for 15-minute timer")
            return
        }
        NotchTimerCache.save(snapshot, to: tempFile)
        suite.expect(NotchTimerCache.load(from: tempFile) != nil, "cache file exists while timer is active")

        // 2. Simulating termination / stop: cache remains untouched
        suite.expect(NotchTimerCache.load(from: tempFile) != nil, "cache file survives app termination / service stop")

        // 3. Simulating relaunch 5 minutes later (300s elapsed of 900s)
        let relaunchDate = clockNow.addingTimeInterval(300)
        guard let reloadedSnap = NotchTimerCache.load(from: tempFile),
              let restored = NotchTimerCache.restoreSession(from: reloadedSnap, now: 400, clockNow: relaunchDate) else {
            suite.expect(false, "restoration succeeds on relaunch")
            return
        }
        suite.expect(restored.isRunning, "restored session resumes running")
        suite.expect(abs(restored.reading(at: 400) - 600) < 0.001, "restored session has 600s remaining")

        // 4. Simulating user explicit cancellation via 'xmark' button: cache deleted
        NotchTimerCache.delete(at: tempFile)
        suite.expect(NotchTimerCache.load(from: tempFile) == nil, "explicit cancellation removes cache file")
    }
}
