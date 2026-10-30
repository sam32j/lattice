// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// The deadline survives preference changes and suspension, so a completed
/// alarm cannot be restarted by a redraw, device change or return from sleep.
final class NotchTimerAlert {
    static let maximumDuration: Duration = .seconds(5 * 60)
    static let alertInterval: Duration = .milliseconds(300)
    static let chimeGap: Duration = .milliseconds(180)
    static let chimeRest: Duration = .milliseconds(800)
    private var task: Task<Void, Never>?
    private var deadline: ContinuousClock.Instant?
    private let firstInterval: Duration
    private let restInterval: Duration
    private let now: () -> ContinuousClock.Instant
    private let sound: () -> Void
    private let secondSound: (() -> Void)?
    private let stopSound: () -> Void

    convenience init() {
        let low = Self.loadPing300msSound(sampleRate: 48000)
        let high = Self.loadPing300msSound(sampleRate: 48000.0 * pow(2.0, 7.0 / 12.0))
        self.init(firstInterval: Self.chimeGap, restInterval: Self.chimeRest, sound: {
            if let low { low.stop(); low.play() }
            else { NSSound.beep() }
        }, secondSound: {
            if let high { high.stop(); high.play() }
            else { NSSound.beep() }
        }, stopSound: {
            low?.stop()
            high?.stop()
        })
    }

    init(interval: Duration = alertInterval, now: @escaping () -> ContinuousClock.Instant = { .now },
         sound: @escaping () -> Void, stopSound: @escaping () -> Void) {
        self.firstInterval = interval
        self.restInterval = interval
        self.now = now
        self.sound = sound
        self.secondSound = nil
        self.stopSound = stopSound
    }

    init(firstInterval: Duration = chimeGap, restInterval: Duration = chimeRest,
         now: @escaping () -> ContinuousClock.Instant = { .now },
         sound: @escaping () -> Void, secondSound: (() -> Void)? = nil,
         stopSound: @escaping () -> Void) {
        self.firstInterval = firstInterval
        self.restInterval = restInterval
        self.now = now
        self.sound = sound
        self.secondSound = secondSound
        self.stopSound = stopSound
    }

    func start(enabled: Bool) {
        let current = now()
        let deadline = self.deadline ?? current.advanced(by: Self.maximumDuration)
        self.deadline = deadline
        guard enabled, current < deadline else { suspend(); return }
        guard task == nil else { return }
        sound()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let second = self.secondSound {
                    let firstDelay = self.delay(until: deadline, interval: self.firstInterval)
                    do { try await Task.sleep(for: firstDelay, clock: .continuous) }
                    catch { return }
                    guard !Task.isCancelled, self.now() < deadline else { self.suspend(); return }
                    second()

                    let restDelay = self.delay(until: deadline, interval: self.restInterval)
                    do { try await Task.sleep(for: restDelay, clock: .continuous) }
                    catch { return }
                    guard !Task.isCancelled, self.now() < deadline else { self.suspend(); return }
                    self.sound()
                } else {
                    let delay = self.delay(until: deadline, interval: self.firstInterval)
                    do { try await Task.sleep(for: delay, clock: .continuous) }
                    catch { return }
                    guard !Task.isCancelled, self.now() < deadline else { self.suspend(); return }
                    self.sound()
                }
            }
        }
    }

    func suspend() {
        task?.cancel(); task = nil
        stopSound()
    }

    func stop() {
        suspend()
        deadline = nil
    }

    private func delay(until deadline: ContinuousClock.Instant, interval: Duration) -> Duration {
        max(.zero, min(interval, now().duration(to: deadline)))
    }

    static func loadPing300msSound(sampleRate: Double = 48000) -> NSSound? {
        guard let raw = try? Data(contentsOf: URL(fileURLWithPath: "/System/Library/Sounds/Ping.aiff")),
              let tone = NotchTimerToneData.make(from: raw, sampleRate: sampleRate) else { return nil }
        return NSSound(data: tone)
    }

    deinit { task?.cancel(); stopSound() }
}
