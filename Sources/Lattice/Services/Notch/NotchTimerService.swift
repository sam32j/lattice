// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Lattice

import AppKit
import Combine

/// Session state is saved to the local machine cache so active timers
/// survive app relaunch, while staying excluded from backups and
/// remote devices.
final class NotchTimerService: ObservableObject {
    static let shared = NotchTimerService()

    @Published private(set) var session = NotchTimerSession()

    private let origin = ContinuousClock.now

    private var completionTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var pomodoroCompletedAt: TimeInterval?
    private var pomodoroAutoDismissTask: Task<Void, Never>?
    private var suspended = true

    private let alert = NotchTimerAlert()

    private let glassSound = NSSound(
        contentsOfFile: "/System/Library/Sounds/Glass.aiff",
        byReference: true
    )

    private let pingSound = NSSound(
        contentsOfFile: "/System/Library/Sounds/Ping.aiff",
        byReference: true
    )

    private init() {}

    var now: TimeInterval {
        let parts = origin.duration(to: .now).components
        return Double(parts.seconds)
            + Double(parts.attoseconds) / 1e18
    }

    // MARK: - Lifecycle

    func syncWithPreferences() {
        guard NotchTimerSupport.isEnabled() else {
            stop()
            return
        }

        suspended = false

        if !session.hasSession {
            restoreSessionFromCache()
        }

        finishIfDue()

        if session.cycleFinished &&
            !NotchService.shared.isTimerPageExpanded {
            schedulePomodoroAutoDismiss()
        }

        if session.completed && session.mode == .timer {
            alert.start(
                enabled: NotchTimerSupport.isSoundEnabled()
            )
        }

        scheduleCompletion()
    }

    func suspend() {
        pomodoroAutoDismissTask?.cancel()
        pomodoroAutoDismissTask = nil
        suspended = true
        persistSessionToCache()

        silenceAlert()

        completionTask?.cancel()
        completionTask = nil

        countdownTask?.cancel()
        countdownTask = nil

        NotchService.shared.endMascotCountdown(
            retreating: false
        )
    }

    func stop() {
        suspend()
    }

    // MARK: - Session controls

    func start(mode: NotchTimerMode, minutes: Int) {
        guard !suspended, NotchTimerSupport.isEnabled()
        else { return }

        guard !session.hasSession else { return }

        silenceAlert()

        session.start(
            mode: mode,
            minutes: minutes,
            now: now,
            configuration: .load()
        )

        persistSessionToCache()
        scheduleCompletion()

        NotchService.shared.reactMascot(.ready)
    }

    func pauseOrResume() {
        guard !suspended, NotchTimerSupport.isEnabled()
        else { return }

        finishIfDue()

        if session.isRunning {
            let timestamp = now
            let deadline = session.deadline
            session.pause(at: timestamp)
            if session.completed {
                handleCompletedPhase(at: timestamp, finishedAt: deadline)
                return
            }
        } else if session.isPaused {
            session.resume(at: now)
        }

        persistSessionToCache()
        scheduleCompletion()
    }

    /// Retained for compatibility with existing callers.
    /// Normal Pomodoro transitions now happen automatically.
    func startNext() {
        guard !suspended, NotchTimerSupport.isEnabled()
        else { return }

        guard session.canStartNext else { return }

        silenceAlert()

        session.startNext(at: now)

        playPhaseSound(
            session.phase == .focus ? pingSound : glassSound
        )

        persistSessionToCache()
        scheduleCompletion()

        NotchService.shared.reactMascot(.ready)
    }

    func cancel() {
        pomodoroAutoDismissTask?.cancel()
        pomodoroAutoDismissTask = nil
        pomodoroCompletedAt = nil
        silenceAlert()

        completionTask?.cancel()
        completionTask = nil

        countdownTask?.cancel()
        countdownTask = nil

        NotchService.shared.endMascotCountdown(
            retreating: false
        )

        session.cancel()
        NotchTimerCache.delete()
    }

    // MARK: - Automatic phase progression

    private func finishIfDue() {
        let timestamp = now
        let deadline = session.deadline

        guard session.finishIfDue(at: timestamp) else {
            return
        }

        handleCompletedPhase(
            at: timestamp,
            finishedAt: deadline
        )
    }

    /// Called once for each completed countdown phase.
    ///
    /// Intermediate Pomodoro phases immediately advance with the existing
    /// sound cue; no separate visual notice is introduced for each phase.
    /// The final phase remains completed until dismissed.
    
    private func handleCompletedPhase(
        at timestamp: TimeInterval,
        finishedAt: TimeInterval? = nil
    ) {
        silenceAlert()

        NotchService.shared.endMascotCountdown(
            retreating: false
        )

        if session.canStartNext {
            // Automatically enter the next phase.
            session.startNext(at: timestamp)

            persistSessionToCache()
            scheduleCompletion()

            switch session.phase {
            case .shortBreak, .longBreak:
                // Focus ended: time for a break.
                playPhaseSound(glassSound)

            case .focus:
                // Break ended: next focus session begins.
                playPhaseSound(pingSound)

            default:
                break
            }
        }  else {
            persistSessionToCache()
            scheduleCompletion()

            if session.mode == .pomodoro {
                pomodoroCompletedAt = timestamp

                playPhaseSound(glassSound)

                if !NotchService.shared.isTimerPageExpanded {
                    schedulePomodoroAutoDismiss()
                }

                NotchService.shared.refreshPresentation()
            } else {
                alert.start(
                    enabled: NotchTimerSupport.isSoundEnabled()
                )
            }
        }
    }


    func pomodoroPresentationDidChange(
        timerPageExpanded: Bool
    ) {
        guard session.cycleFinished else { return }

        if timerPageExpanded {
            // Opening a completed compact strip acknowledges it.
            cancel()
        } else {
            // Closing the expanded page uses the acknowledgment window.
            schedulePomodoroAutoDismiss()
        }
    }

    func dismissCompletedPomodoroFromStrip() {
        guard session.cycleFinished else { return }
        cancel()
    }

    private func schedulePomodoroAutoDismiss() {
        pomodoroAutoDismissTask?.cancel()
        pomodoroAutoDismissTask = nil

        guard session.cycleFinished,
            let completedAt = pomodoroCompletedAt else {
            return
        }

        let remaining = 10 - (now - completedAt)

        guard remaining > 0 else {
            cancel()
            return
        }

        pomodoroAutoDismissTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(remaining),
                    clock: .continuous
                )
            } catch {
                return
            }

            guard let self,
                !Task.isCancelled,
                self.session.cycleFinished,
                !NotchService.shared.isTimerPageExpanded else {
                return
            }

            self.pomodoroAutoDismissTask = nil
            self.cancel()
            NotchService.shared.refreshPresentation()
        }
    }


    
    // MARK: - Completion sound

    private func playPhaseSound(_ sound: NSSound?) {
        guard NotchTimerSupport.isSoundEnabled() else {
            return
        }

        sound?.stop()
        sound?.play()
    }

    private func silenceAlert() {
        alert.stop()
        glassSound?.stop()
        pingSound?.stop()
    }


    // MARK: - Persistence

    private func persistSessionToCache() {
        // Only live or paused phases are cached.
        // Completed sessions have already announced.
        guard !session.completed else {
            NotchTimerCache.delete()
            return
        }

        if let snapshot = NotchTimerCache.createSnapshot(
            from: session,
            now: now
        ) {
            NotchTimerCache.save(snapshot)
        } else {
            NotchTimerCache.delete()
        }
    }

    private func restoreSessionFromCache() {
        guard let snapshot = NotchTimerCache.load()
        else { return }

        guard let restored = NotchTimerCache.restoreSession(
            from: snapshot,
            now: now
        ) else {
            NotchTimerCache.delete()
            return
        }

        session = restored

        if session.completed {
            // An expired cached phase advances only once.
            // Its successor starts now, not at the old
            // deadline, preventing fabricated cycles.
            handleCompletedPhase(at: now)
        }
    }

    // MARK: - Scheduling

    private func scheduleCompletion() {
        completionTask?.cancel()
        completionTask = nil

        scheduleCountdown()

        guard !suspended,
            let deadline = session.deadline else {
            return
        }

        let remaining = max(0, deadline - now)

        completionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(remaining),
                    clock: .continuous
                )
            } catch {
                return
            }

            guard let self,
                !Task.isCancelled,
                !self.suspended,
                NotchTimerSupport.isEnabled() else {
                return
            }

            self.completionTask = nil
            self.finishIfDue()
        }
    }

    /// The companion comes out for a countdown's last seconds.
    /// Paused, the countdown sends it back behind the camera.
    private func scheduleCountdown() {
        countdownTask?.cancel()
        countdownTask = nil

        guard !suspended,
            let deadline = session.deadline else {
            NotchService.shared.endMascotCountdown(
                retreating: true
            )
            return
        }

        let remaining = deadline - now

        guard remaining > 1.5 else {
            return
        }

        let wait = max(
            0,
            remaining - NotchMascotMotion.countdownLead
        )

        countdownTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(wait),
                    clock: .continuous
                )
            } catch {
                return
            }

            guard let self,
                !Task.isCancelled,
                !self.suspended,
                let deadline = self.session.deadline else {
                return
            }

            self.countdownTask = nil

            NotchService.shared.watchMascotCountdown(
                remaining: deadline - self.now
            )
        }
    }
}
