// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Follow production extensions when verifying a tap owner's session wiring.
/// Missing source fails closed through the caller's existing nonempty guard.
enum InputTapSessionSources {
    static func read(_ owner: String) -> String {
        var paths = [owner]
        if owner == "Sources/Lattice/Services/QuitProtection/QuitProtectionService.swift" {
            paths += ["Sources/Lattice/Services/QuitProtection/QuitProtectionRouting.swift",
                      "Sources/Lattice/Services/QuitProtection/QuitProtectionPending.swift"]
        }
        do {
            return try paths.map { try String(contentsOfFile: $0, encoding: .utf8) }
                .joined(separator: "\n")
        } catch { return "" }
    }
}
