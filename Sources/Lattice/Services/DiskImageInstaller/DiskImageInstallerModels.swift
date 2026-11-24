// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// A mounted disk image waiting to be installed, as the App Installer tab
/// shows it. The details beyond the name arrive a moment later: they read the
/// bundle, the image file and its code signature.
struct DetectedDiskImage: Equatable {
    enum Phase: Equatable {
        case waiting
        case installing(DiskImageInstallStep)
    }

    let id: UUID
    let displayName: String
    let appPath: String
    let imageFileName: String
    var version: String?
    var imageSize: Int64?
    var developer: String?
    /// Nil until checked; false when the signature or Gatekeeper refuses it.
    var gatekeeperAccepted: Bool?
    var phase: Phase = .waiting
}

/// The stages of an install, in order, for the tab's progress bar.
enum DiskImageInstallStep: Int, Equatable, CaseIterable {
    case copying, verifying, moving, ejecting, trashing

    /// How far along the bar this step starts.
    var progress: Double {
        switch self {
        case .copying: return 0.18
        case .verifying: return 0.54
        case .moving: return 0.72
        case .ejecting: return 0.86
        case .trashing: return 0.94
        }
    }
}

/// One app installed from a disk image, kept for the Recent Installs list.
struct DiskImageRecentInstall: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let version: String?
    let destinationPath: String
    let downloadTrashed: Bool
    let date: Date
}

enum DiskImageRecentInstalls {
    static let limit = 8

    static func load(from defaults: UserDefaults = .standard) -> [DiskImageRecentInstall] {
        guard let data = defaults.data(forKey: DefaultsKey.diskImageInstallerRecentInstalls),
              let list = try? JSONDecoder().decode([DiskImageRecentInstall].self, from: data) else { return [] }
        return list
    }

    /// The newest first, one entry per destination, at most `limit`.
    static func adding(_ install: DiskImageRecentInstall, to list: [DiskImageRecentInstall]) -> [DiskImageRecentInstall] {
        Array(([install] + list.filter { $0.destinationPath != install.destinationPath }).prefix(limit))
    }

    static func save(_ list: [DiskImageRecentInstall], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: DefaultsKey.diskImageInstallerRecentInstalls)
    }

    /// The signer's name from `codesign -dv` output: the first Developer ID
    /// authority, without its certificate kind and team identifier.
    static func developer(fromCodesignOutput output: String) -> String? {
        for line in output.split(separator: "\n") where line.hasPrefix("Authority=") {
            var name = line.dropFirst("Authority=".count)
            for prefix in ["Developer ID Application: ", "Apple Distribution: ", "Apple Development: "]
                where name.hasPrefix(prefix) {
                name = name.dropFirst(prefix.count)
                if let team = name.range(of: " (", options: .backwards), name.hasSuffix(")") {
                    name = name[..<team.lowerBound]
                }
                return String(name)
            }
        }
        return nil
    }
}
