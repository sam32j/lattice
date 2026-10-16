// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum DownstreamIdentity {
    static let name = "Lattice"
    static let bundleID = "io.github.sam32j.lattice"
    static let repository = "sam32j/lattice"
    // Set this public pin to YOUR Developer ID team before distributing updates,
    // or "ADHOC" for personal ad-hoc self-signed distribution.
    static let signingTeamID = "7L763852RV"

    static func requirements(teamID: String) -> (app: String, dmg: String)? {
        if teamID == "ADHOC" {
            return ("identifier \"\(bundleID)\"", "identifier \"\(bundleID)\"")
        }
        guard teamID.range(of: #"^[A-Z0-9]{10}$"#, options: .regularExpression) != nil,
              teamID != "3D485NHW29" else { return nil }
        let signer = "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
        return ("identifier \"\(bundleID)\" and \(signer)", signer)
    }

    // Mutually exclusive identifiers fail closed without an official-team fallback.
    static let unavailableRequirement = "identifier \"lattice.unconfigured\" and identifier \"lattice.denied\""
    static var appRequirement: String {
        requirements(teamID: signingTeamID)?.app ?? unavailableRequirement
    }
    static var dmgRequirement: String {
        requirements(teamID: signingTeamID)?.dmg ?? unavailableRequirement
    }
}
