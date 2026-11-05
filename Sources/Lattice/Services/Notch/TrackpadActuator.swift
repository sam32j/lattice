// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation

/// Drives the physical Force Touch trackpad Taptic Engine via MultitouchSupport.
/// Provides direct hardware waveforms (such as level 6 strong tap) matching the mactic utility.
final class TrackpadActuator {
    static let shared = TrackpadActuator()

    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    private typealias ActuatorCreateFn = @convention(c) (UInt64) -> Unmanaged<CFTypeRef>?
    private typealias ActuatorOpenFn = @convention(c) (CFTypeRef, UInt32) -> Int32
    private typealias ActuatorCloseFn = @convention(c) (CFTypeRef) -> Int32
    private typealias ActuatorActuateFn = @convention(c) (CFTypeRef, Int32, UInt32, UInt32, UInt32) -> Int32

    private let queue = DispatchQueue(label: "io.github.sam32j.lattice.trackpad-actuator", qos: .userInteractive)
    private var handle: UnsafeMutableRawPointer?
    private var createList: CreateListFn?
    private var actCreate: ActuatorCreateFn?
    private var actOpen: ActuatorOpenFn?
    private var actClose: ActuatorCloseFn?
    private var actActuate: ActuatorActuateFn?

    private var cachedDeviceID: UInt64?
    private var hasResolvedSymbols = false

    private init() {
        resolveSymbols()
    }

    private func resolveSymbols() {
        guard !hasResolvedSymbols else { return }
        hasResolvedSymbols = true
        guard let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            return
        }
        handle = h
        if let sym = dlsym(h, "MTDeviceCreateList") {
            createList = unsafeBitCast(sym, to: CreateListFn.self)
        }
        if let sym = dlsym(h, "MTActuatorCreateFromDeviceID") {
            actCreate = unsafeBitCast(sym, to: ActuatorCreateFn.self)
        }
        if let sym = dlsym(h, "MTActuatorOpen") {
            actOpen = unsafeBitCast(sym, to: ActuatorOpenFn.self)
        }
        if let sym = dlsym(h, "MTActuatorClose") {
            actClose = unsafeBitCast(sym, to: ActuatorCloseFn.self)
        }
        if let sym = dlsym(h, "MTActuatorActuate") {
            actActuate = unsafeBitCast(sym, to: ActuatorActuateFn.self)
        }
    }

    var isAvailable: Bool {
        createList != nil && actCreate != nil && actOpen != nil && actClose != nil && actActuate != nil
    }

    /// Triggers a low-level haptic waveform on the Force Touch trackpad asynchronously.
    /// Waveform 6 matches mactic's strong tap feedback.
    func actuate(waveform: Int32 = 6) {
        guard isAvailable else { return }
        queue.async { [weak self] in
            self?.performActuation(waveform: waveform)
        }
    }

    private func performActuation(waveform: Int32) {
        guard let actCreate, let actOpen, let actClose, let actActuate else { return }

        let devID: UInt64
        if let cached = cachedDeviceID {
            devID = cached
        } else {
            guard let createList, let devices = createList()?.takeRetainedValue() else { return }
            let count = CFArrayGetCount(devices)
            guard count > 0 else { return }
            var foundID: UInt64?
            for i in 0..<count {
                guard let dev = CFArrayGetValueAtIndex(devices, i) else { continue }
                let id = dev.advanced(by: 64).load(as: UInt64.self)
                if let act = actCreate(id)?.takeRetainedValue() {
                    let ret = actOpen(act, 0)
                    if ret == 0 {
                        _ = actClose(act)
                        foundID = id
                        break
                    }
                }
            }
            guard let validID = foundID else { return }
            cachedDeviceID = validID
            devID = validID
        }

        guard let actuator = actCreate(devID)?.takeRetainedValue() else {
            cachedDeviceID = nil
            return
        }
        guard actOpen(actuator, 0) == 0 else {
            cachedDeviceID = nil
            return
        }
        _ = actActuate(actuator, waveform, 0, 0, 0)
        _ = actClose(actuator)
    }
}
