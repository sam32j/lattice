// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation
import UniformTypeIdentifiers

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
    /// The app is already installed; installing replaces that copy.
    var replacesExisting = false
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

extension DiskImageInstallerSupport {
    /// The mount point `hdiutil attach -plist` reports for the image's volume.
    static func mountPoint(fromAttachPlist data: Data) -> URL? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else { return nil }
        return entities.lazy.compactMap { $0["mount-point"] as? String }.first.map { URL(fileURLWithPath: $0) }
    }
}

/// Whether double-clicking a disk image opens it in Lattice, which asks
/// before installing, or in macOS's own Disk Image Mounter.
enum DiskImageOpenHandler {
    static let mounterURL = URL(fileURLWithPath: "/System/Library/CoreServices/DiskImageMounter.app")
    /// The .dmg type, the one a downloaded disk image has.
    static let contentTypes = ["com.apple.disk-image-udif"].compactMap { UTType($0) }

    /// By bundle identifier, so another copy of this same app counts too.
    static var opensInLattice: Bool {
        guard let type = contentTypes.first,
              let handler = NSWorkspace.shared.urlForApplication(toOpen: type) else { return false }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// Makes Lattice, or Disk Image Mounter again, the app DMG files open in.
    /// macOS confirms the change with its own dialog; the completion reports
    /// whether Lattice is the opener afterwards, so a declined change shows.
    @MainActor
    static func setOpensInLattice(_ on: Bool, completion: @escaping (Bool) -> Void) {
        guard let type = contentTypes.first else { completion(opensInLattice); return }
        let app = on ? Bundle.main.bundleURL : mounterURL
        // macOS's confirmation takes key focus while Lattice stays the active
        // app, and the Settings window drew its inactive look for as long as
        // it was up: every accent went grey and came back, a blink. The
        // window keeps its active look until key focus returns.
        // macOS does not always hand key focus back when its dialog closes,
        // so the window that had it gets it back.
        let window = NSApp.keyWindow
        SettingsActiveLookHold.shared.isHolding = true
        NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type) { _ in
            DispatchQueue.main.async {
                completion(opensInLattice)
                if NSApp.isActive, let window, window.isVisible, !window.isKeyWindow { window.makeKey() }
                SettingsActiveLookHold.shared.releaseWhenKeyReturns()
            }
        }
    }

    /// Opens an image the way a plain double-click would without Lattice.
    static func openWithDiskImageMounter(_ url: URL) {
        NSWorkspace.shared.open([url], withApplicationAt: mounterURL, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Keeps the Settings window drawing as the key window while a system
/// confirmation Lattice asked for holds key focus, so the window does not
/// blink to its inactive look and back.
@MainActor
final class SettingsActiveLookHold: ObservableObject {
    static let shared = SettingsActiveLookHold()
    @Published var isHolding = false

    /// Releases once a Lattice window is key again, or after a moment if
    /// none becomes key (the person clicked elsewhere).
    func releaseWhenKeyReturns() {
        func check(_ attempt: Int) {
            if NSApp.keyWindow != nil || attempt >= 20 {
                isHolding = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { check(attempt + 1) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { check(0) }
    }
}
