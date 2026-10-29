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
              raw.count >= 54,
              raw.starts(with: [0x46, 0x4F, 0x52, 0x4D])
        else {
            return NSSound(contentsOfFile: "/System/Library/Sounds/Ping.aiff", byReference: false)
        }
        var data = raw
        let frames: UInt32 = UInt32(sampleRate * 0.3) // 300ms at given sample rate
        let audioBytes: UInt32 = frames * 6 // 2 ch * 3 bytes (24-bit)
        let ssndChunkSize: UInt32 = 8 + audioBytes
        let formChunkSize: UInt32 = 4 + 26 + 8 + ssndChunkSize
        guard data.count >= Int(54 + audioBytes) else {
            return NSSound(data: data)
        }

        func writeBigEndian(_ value: UInt32, at offset: Int) {
            var be = value.bigEndian
            withUnsafeBytes(of: &be) { bytes in
                data.replaceSubrange(offset..<(offset + 4), with: bytes)
            }
        }

        writeBigEndian(formChunkSize, at: 4)
        writeBigEndian(frames, at: 22)
        writeBigEndian(ssndChunkSize, at: 42)

        var exp = 16382
        var d = sampleRate
        while d >= 1.0 { d /= 2.0; exp += 1 }
        let mantissa = UInt64(d * Double(UInt64.max))
        var expBe = UInt16(exp).bigEndian
        var mantBe = mantissa.bigEndian
        withUnsafeBytes(of: &expBe) { data.replaceSubrange(28..<30, with: $0) }
        withUnsafeBytes(of: &mantBe) { data.replaceSubrange(30..<38, with: $0) }

        let fadeFrames = Int(sampleRate * 0.005)
        let audioStart = 54
        let fadeStartFrame = Int(frames) - fadeFrames
        for i in 0..<fadeFrames {
            let frameIndex = fadeStartFrame + i
            let factor = Double(fadeFrames - 1 - i) / Double(fadeFrames)
            let frameOffset = audioStart + frameIndex * 6
            for ch in 0..<2 {
                let chOffset = frameOffset + ch * 3
                let b0 = Int32(data[chOffset])
                let b1 = Int32(data[chOffset + 1])
                let b2 = Int32(data[chOffset + 2])
                var sample = (b0 << 24) | (b1 << 16) | (b2 << 8)
                sample = Int32(Double(sample) * factor)
                data[chOffset] = UInt8(truncatingIfNeeded: (sample >> 24) & 0xFF)
                data[chOffset + 1] = UInt8(truncatingIfNeeded: (sample >> 16) & 0xFF)
                data[chOffset + 2] = UInt8(truncatingIfNeeded: (sample >> 8) & 0xFF)
            }
        }

        let slicedData = data.prefix(Int(54 + audioBytes))
        return NSSound(data: Data(slicedData))
    }

    deinit { task?.cancel(); stopSound() }
}
