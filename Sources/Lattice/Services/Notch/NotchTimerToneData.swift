// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum NotchTimerToneData {
    static func make(from raw: Data, sampleRate: Double) -> Data? {
        guard raw.startIndex == 0, raw.count >= 54, sampleRate.isFinite,
              sampleRate > 0, sampleRate <= 192_000,
              raw[0..<4].elementsEqual("FORM".utf8), raw[8..<12].elementsEqual("AIFF".utf8),
              raw[12..<16].elementsEqual("COMM".utf8), raw[16..<20].elementsEqual([0, 0, 0, 18]),
              raw[20..<22].elementsEqual([0, 2]), raw[26..<28].elementsEqual([0, 24]),
              raw[38..<42].elementsEqual("SSND".utf8), raw[46..<54].allSatisfy({ $0 == 0 }) else { return nil }
        func word(at offset: Int) -> Int {
            raw[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
        }
        let sourceFrames = word(at: 22)
        let soundSize = word(at: 42)
        let formEnd = word(at: 4) + 8
        guard sourceFrames > 0, soundSize >= 8 + sourceFrames * 6,
              formEnd >= 46 + soundSize, formEnd <= raw.count else { return nil }
        var data = raw
        let frames: UInt32 = UInt32(sampleRate * 0.3) // 300ms at given sample rate
        let audioBytes: UInt32 = frames * 6 // 2 ch * 3 bytes (24-bit)
        let ssndChunkSize: UInt32 = 8 + audioBytes
        let formChunkSize: UInt32 = 4 + 26 + 8 + ssndChunkSize
        guard frames > 0, Int(frames) <= sourceFrames, data.count >= Int(54 + audioBytes) else { return nil }

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
        return Data(slicedData)
    }
}
