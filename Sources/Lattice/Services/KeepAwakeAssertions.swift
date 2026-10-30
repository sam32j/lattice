// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import IOKit.pwr_mgt

/// Owns the native resources. Dependencies are injectable so failures can be
/// exercised without changing the test Mac's sleep behavior.
final class KeepAwakeAssertions {
    enum Kind { case system, display }
    private var system: IOPMAssertionID?
    private var display: IOPMAssertionID?
    private let create: (Kind) -> IOPMAssertionID?
    private let releaseID: (IOPMAssertionID) -> Bool
    private let isValid: (IOPMAssertionID) -> Bool

    init(create: @escaping (Kind) -> IOPMAssertionID? = KeepAwakeAssertions.createNative,
         release: @escaping (IOPMAssertionID) -> Bool = { IOPMAssertionRelease($0) == kIOReturnSuccess },
         isValid: @escaping (IOPMAssertionID) -> Bool = KeepAwakeAssertions.isNativeActive) {
        self.create = create
        self.releaseID = release
        self.isValid = isValid
    }

    var hasAssertions: Bool { system != nil || display != nil }

    func acquire(allowDisplaySleep: Bool) -> Bool {
        if let id = system, !isValid(id) { _ = releaseID(id); system = nil }
        if let id = display, !isValid(id) { _ = releaseID(id); display = nil }
        if system == nil { system = create(.system) }
        guard system != nil else { _ = release(); return false }
        if allowDisplaySleep {
            if let id = display {
                guard releaseID(id) else { return false }
                display = nil
            }
        } else if display == nil {
            display = create(.display)
            guard display != nil else { _ = release(); return false }
        }
        return true
    }

    @discardableResult
    func release() -> Bool {
        if let id = display, releaseID(id) || !isValid(id) { display = nil }
        if let id = system, releaseID(id) || !isValid(id) { system = nil }
        return !hasAssertions
    }

    private static func isNativeActive(_ id: IOPMAssertionID) -> Bool {
        guard let properties = IOPMAssertionCopyProperties(id)?.takeRetainedValue() as? [String: Any] else { return false }
        return (properties[kIOPMAssertionLevelKey] as? NSNumber)?.intValue == kIOPMAssertionLevelOn
    }

    private static func createNative(_ kind: Kind) -> IOPMAssertionID? {
        var id = IOPMAssertionID(0)
        let type = kind == .system ? "PreventUserIdleSystemSleep" : "PreventUserIdleDisplaySleep"
        let status = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "Lattice: Stay Awake" as CFString, &id)
        return status == kIOReturnSuccess ? id : nil
    }
}
