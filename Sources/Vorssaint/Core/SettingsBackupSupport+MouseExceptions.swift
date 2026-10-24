// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

extension SettingsBackupSupport {
    static func restoredMouseShortcutExceptions(restored: [String: [String]],
                                                local: [String: [String]],
                                                inherited: [String] = []) -> [String: [String]] {
        var result = restored
        for (button, apps) in local {
            let paths = pathIdentities(in: apps)
            if !paths.isEmpty {
                result[button] = restoredExceptionList(restored: result[button] ?? inherited, carried: paths)
            }
        }
        return result
    }

    /// The half of an exception list a backup file never carries, because
    /// `portableMouseExceptions` filters it out on the way out.
    static func pathIdentities(in list: [String]) -> [String] {
        list.filter(MouseAppExceptionSupport.isExecutablePathIdentity)
    }

    /// What an exception list should hold once a backup has been applied.
    /// Restoring clears every exported key before writing the file's values,
    /// and the file only has the portable half -- so without carrying the
    /// paths across, applying a backup would delete the entries for programs
    /// that are not apps, including on the Mac the backup was written on. The
    /// restored order wins and a carried path already present is not doubled,
    /// so applying the same backup twice lands on the same list. All five keys
    /// register `[String]()`, so after the clear the read is `[]` rather than
    /// the pre-restore list -- which is what makes this safe on a backup
    /// written before these keys existed, and not only on one that carries an
    /// empty array. (Reasoning from @PathGao's review.)
    static func restoredExceptionList(restored: [String], carried: [String]) -> [String] {
        restored + carried.filter { !restored.contains($0) }
    }

    /// A mouse exception list holds two kinds of identity at once: a bundle
    /// identifier, which names the same app on any Mac, and the resolved path
    /// of a program that has no identifier to be named by (issue #1009). The
    /// never-exported list above already refuses the second kind wherever it
    /// has a key to itself -- `commandBarFileScopes`,
    /// `mediaImageWatermarkLogoPath`, `brightnessDDCWriteOnlyPaths`, all for
    /// the same stated reason: authority on one Mac, not portable
    /// configuration. Here the two kinds share one array, so the refusal has
    /// to be per value rather than per key. Left in, a backup would carry the
    /// short username inside the path, and restoring it on another Mac would
    /// leave a row pointing at a file that is not there -- which
    /// `valueLooksRight` cannot catch, since the value is a perfectly good
    /// `[String]`.
    ///
    /// Driven from `MouseExceptionScope.allCases` rather than a list of keys
    /// spelled here, so a scope that renames its key, or two scopes that come
    /// to share one, are covered without this file being edited.
    static func portableMouseExceptions(_ source: [String: Any]) -> [String: Any] {
        var settings = source
        for key in Set(MouseExceptionScope.allCases.map(\.defaultsKey)) {
            guard let stored = settings[key] as? [String] else { continue }
            let portable = stored.filter { !MouseAppExceptionSupport.isExecutablePathIdentity($0) }
            guard portable.count != stored.count else { continue }
            // An emptied list still means "no exceptions", so the key stays
            // rather than falling back to whatever a missing key would do.
            settings[key] = portable
        }
        if let lists = settings[DefaultsKey.mouseShortcutAppExceptions] as? [String: [String]] {
            settings[DefaultsKey.mouseShortcutAppExceptions] = lists.mapValues { apps in
                apps.filter { !MouseAppExceptionSupport.isExecutablePathIdentity($0) }
            }
        }
        return settings
    }

}
