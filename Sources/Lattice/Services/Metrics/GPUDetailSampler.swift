// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Darwin
import Foundation
import IOKit
import Metal

enum SystemWidgetHardware {
    static let cpuModel: String? = {
        var size = 0
        let key = "machdep.cpu.brand_string"
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &bytes, &size, nil, 0) == 0 else { return nil }
        return String(cString: bytes)
    }()

    static let cpuCoreCount: Int = {
        var count: Int32 = 0
        var size = MemoryLayout.size(ofValue: count)
        guard sysctlbyname("hw.physicalcpu", &count, &size, nil, 0) == 0, count > 0 else {
            return ProcessInfo.processInfo.processorCount
        }
        return Int(count)
    }()

    static let gpu: (model: String?, coreCount: Int?) = {
        #if arch(arm64)
        let accelerator = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        if accelerator != IO_OBJECT_NULL {
            defer { IOObjectRelease(accelerator) }
            let model = IORegistryEntryCreateCFProperty(accelerator, "model" as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            let cores = IORegistryEntryCreateCFProperty(accelerator, "gpu-core-count" as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
            return (model.map { "\($0) GPU" } ?? "Apple Silicon GPU", cores.flatMap { $0 > 0 ? $0 : nil })
        }
        #endif
        return (MTLCreateSystemDefaultDevice()?.name, nil)
    }()

    static func coreUsage(_ name: String, readings: [Double?]) -> Double? {
        let values = CPUCoreTopology.groups(for: readings.count)
            .filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            .flatMap(\.indices)
            .compactMap { readings[$0] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

/// Samples Apple Silicon's GPU energy and frequency-state residency on the
/// monitor queue. IOReport is optional and resolved at runtime. See Netdata's
/// macOS GPU collector for the counter names and the pmgr frequency table.
final class GPUDetailSampler {
    struct Reading {
        var watts: Double?
        var megahertz: Double?
    }

    private lazy var counters = GPUReportCounters()
    private var previous: (sample: CFDictionary, time: TimeInterval)?

    func reset() { previous = nil }

    func sample(now: TimeInterval) -> Reading {
        guard let counters, let current = counters.sample() else {
            reset()
            return Reading()
        }
        let baseline = previous
        previous = (current, now)
        guard let baseline, now > baseline.time, now - baseline.time < 30 else { return Reading() }
        return counters.read(from: baseline.sample, to: current, elapsed: now - baseline.time)
    }
}

private final class GPUReportCounters {
    private typealias CopyChannels = @convention(c) (UInt64, UInt64) -> Unmanaged<CFDictionary>?
    private typealias Subscribe = @convention(c) (
        CFTypeRef?, CFMutableDictionary, UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, UInt64, CFTypeRef?
    ) -> Unmanaged<CFTypeRef>?
    private typealias Sample = @convention(c) (CFTypeRef, CFMutableDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias Delta = @convention(c) (CFDictionary, CFDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias ChannelString = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias Counter = @convention(c) (CFDictionary, Int32) -> Int64
    private typealias Count = @convention(c) (CFDictionary) -> Int32
    private typealias StateName = @convention(c) (CFDictionary, Int32) -> Unmanaged<CFString>?

    private static let library = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY | RTLD_LOCAL)
    private let subscription: CFTypeRef
    private let channels: CFMutableDictionary
    private let takeSample: Sample
    private let takeDelta: Delta
    private let channelName: ChannelString
    private let unitName: ChannelString
    private let energy: Counter
    private let stateCount: Count
    private let stateName: StateName
    private let residency: Counter
    private let frequencies: [Double]

    init?() {
        #if arch(arm64)
        guard let library = Self.library else { return nil }
        func symbol<T>(_ name: String, _: T.Type) -> T? {
            dlsym(library, name).map { unsafeBitCast($0, to: T.self) }
        }

        guard let copy = symbol("IOReportCopyAllChannels", CopyChannels.self),
              let subscribe = symbol("IOReportCreateSubscription", Subscribe.self),
              let sample = symbol("IOReportCreateSamples", Sample.self),
              let delta = symbol("IOReportCreateSamplesDelta", Delta.self),
              let group = symbol("IOReportChannelGetGroup", ChannelString.self),
              let name = symbol("IOReportChannelGetChannelName", ChannelString.self),
              let unit = symbol("IOReportChannelGetUnitLabel", ChannelString.self),
              let energy = symbol("IOReportSimpleGetIntegerValue", Counter.self),
              let stateCount = symbol("IOReportStateGetCount", Count.self),
              let stateName = symbol("IOReportStateGetNameForIndex", StateName.self),
              let residency = symbol("IOReportStateGetResidency", Counter.self),
              let all = copy(0, 0)?.takeRetainedValue(),
              let channels = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, all) else { return nil }

        let selected = Self.entries(all).filter { channel in
            switch (Self.string(group(channel)), Self.string(name(channel))) {
            case ("Energy Model", "GPU Energy"), ("Energy Model", "GPU"), ("GPU Stats", "GPUPH"):
                return true
            default: return false
            }
        }
        guard !selected.isEmpty else { return nil }
        let selectedArray = selected as CFArray
        let key = "IOReportChannels" as CFString
        CFDictionarySetValue(channels, Unmanaged.passUnretained(key).toOpaque(),
                             Unmanaged.passUnretained(selectedArray).toOpaque())
        var subscribedChannels: Unmanaged<CFMutableDictionary>?
        let subscription = subscribe(nil, channels, &subscribedChannels, 0, nil)?.takeRetainedValue()
        _ = subscribedChannels?.takeRetainedValue()
        guard let subscription else { return nil }

        self.subscription = subscription
        self.channels = channels
        takeSample = sample
        takeDelta = delta
        channelName = name
        unitName = unit
        self.energy = energy
        self.stateCount = stateCount
        self.stateName = stateName
        self.residency = residency
        frequencies = Self.gpuFrequencies()
        #else
        return nil
        #endif
    }

    func sample() -> CFDictionary? {
        takeSample(subscription, channels, nil)?.takeRetainedValue()
    }

    func read(from previous: CFDictionary, to current: CFDictionary, elapsed: TimeInterval) -> GPUDetailSampler.Reading {
        guard let delta = takeDelta(previous, current, nil)?.takeRetainedValue() else { return .init() }
        var reading = GPUDetailSampler.Reading()
        var energyWatts: [String: Double] = [:]
        for channel in Self.entries(delta) {
            guard let name = Self.string(channelName(channel)) else { continue }
            if name == "GPUPH" {
                reading.megahertz = averageClock(channel)
            } else if let factor = ["mJ": 1e3, "uJ": 1e6, "nJ": 1e9][Self.string(unitName(channel)) ?? ""] {
                let count = energy(channel, 0)
                if count >= 0 { energyWatts[name, default: 0] += Double(count) / factor / elapsed }
            }
        }
        reading.watts = energyWatts["GPU Energy"] ?? energyWatts["GPU"]
        return reading
    }

    private func averageClock(_ channel: CFDictionary) -> Double? {
        let count = stateCount(channel)
        guard (1...64).contains(count), !frequencies.isEmpty else { return nil }
        var activeTicks = 0.0
        var weightedMHz = 0.0
        var observedState = false
        for index in 0..<count {
            let ticks = Double(residency(channel, index))
            guard ticks >= 0, let name = Self.string(stateName(channel, index)) else { return nil }
            guard name.hasPrefix("P"), let state = Int(name.dropFirst()) else { continue }
            if frequencies.indices.contains(state), frequencies[state] > 0 {
                observedState = true
                activeTicks += ticks
                weightedMHz += ticks * frequencies[state]
            } else if ticks > 0 {
                // Drivers can list more states than this chip supports.
                // A populated unknown state cannot be mapped to a real clock.
                return nil
            }
        }
        guard observedState else { return nil }
        return activeTicks > 0 ? weightedMHz / activeTicks : 0
    }

    private static func string(_ value: Unmanaged<CFString>?) -> String? {
        value.map { $0.takeUnretainedValue() as String }
    }

    private static func entries(_ dictionary: CFDictionary) -> [CFDictionary] {
        let key = "IOReportChannels" as CFString
        guard let value = CFDictionaryGetValue(dictionary, Unmanaged.passUnretained(key).toOpaque()) else { return [] }
        return Unmanaged<CFArray>.fromOpaque(value).takeUnretainedValue() as? [CFDictionary] ?? []
    }

    private static func gpuFrequencies() -> [Double] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("pmgr"))
        guard service != IO_OBJECT_NULL else { return [] }
        defer { IOObjectRelease(service) }
        guard let data = IORegistryEntryCreateCFProperty(service, "voltage-states9" as CFString,
                                                         kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data,
              data.count >= 16, data.count.isMultiple(of: 8) else { return [] }
        return data.withUnsafeBytes { bytes in
            stride(from: 0, to: data.count, by: 8).map { offset in
                let value = UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
                return Double(value) / 1_000_000
            }
        }
    }
}
