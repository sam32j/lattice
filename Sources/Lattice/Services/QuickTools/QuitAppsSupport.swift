// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Samuel Ji

/// Which running apps a batch quit asks to quit. Adopted from upstream's Quit
/// apps window (v3.4.3), whose targeting rules Lattice serves from the Command
/// Bar instead of a separate panel. Kept free of AppKit for the unit harness.
enum QuitAppsSupport {
    /// Lattice's own identifiers, including the local signing variant. Quitting
    /// ourselves mid-sweep would leave the remaining apps running with no way
    /// to finish the pass from here.
    static let latticeBundleIdentifiers = [
        DownstreamIdentity.bundleID,
        DownstreamIdentity.bundleID + ".dev",
    ]

    /// `NSApplication.ActivationPolicy.regular.rawValue`.
    static let regularActivationPolicy = 0

    /// Auto Quit's locked pair, Finder and Phone, always keeps running.
    static var keptBundleIdentifiers: Set<String> {
        Set(Defaults.mandatoryAutoQuitExceptionBundleIDs)
    }

    /// Whether a running app should receive a soft quit. Only regular GUI apps
    /// with a bundle id, still alive, and outside the kept set qualify.
    static func shouldQuitApp(bundleIdentifier: String?,
                              activationPolicyRawValue: Int,
                              isTerminated: Bool,
                              exceptions: Set<String>) -> Bool {
        guard !isTerminated else { return false }
        guard activationPolicyRawValue == regularActivationPolicy else { return false }
        guard let bundleIdentifier, !bundleIdentifier.isEmpty,
              !latticeBundleIdentifiers.contains(bundleIdentifier) else { return false }
        return !exceptions.contains(bundleIdentifier)
    }

    /// The apps a batch quit sends `terminate()` to, in their original order.
    /// Keeping the frontmost app only removes that one process.
    static func batchQuitTargets(_ apps: [QuitAppsCandidate],
                                 exceptions: Set<String> = keptBundleIdentifiers,
                                 keepingPID: Int32?) -> [QuitAppsCandidate] {
        apps.filter { app in
            app.pid != keepingPID
                && shouldQuitApp(bundleIdentifier: app.bundleIdentifier,
                                 activationPolicyRawValue: app.activationPolicyRawValue,
                                 isTerminated: app.isTerminated,
                                 exceptions: exceptions)
        }
    }
}

/// One running app as a batch quit sees it, reduced to the facts the
/// targeting rules read.
struct QuitAppsCandidate: Equatable {
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let activationPolicyRawValue: Int
    let isTerminated: Bool
}
