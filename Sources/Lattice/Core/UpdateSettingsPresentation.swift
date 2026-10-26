// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum AppUpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case downloading(progress: Double?)
    case installing
    case failed(String)
}

enum SystemTimeZone {
    static var current: TimeZone {
        if let link = try? FileManager.default.destinationOfSymbolicLink(atPath: "/etc/localtime"),
           let range = link.range(of: "zoneinfo/"),
           let zone = TimeZone(identifier: String(link[range.upperBound...])) {
            return zone
        }
        return .autoupdatingCurrent
    }
}

/// Actions depend only on the current operation, never earlier session history.
struct UpdateSettingsPresentation {
    let state: AppUpdateState
    var canCheck: Bool {
        switch state {
        case .checking, .downloading, .installing: return false
        case .idle, .upToDate, .available, .failed: return true
        }
    }
    var reviewVersion: String? {
        if case let .available(version) = state { return version }
        return nil
    }

    static func formattedLastChecked(_ date: Date,
                                    timeZone: TimeZone = SystemTimeZone.current,
                                    locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        formatter.locale = locale
        return formatter.string(from: date)
    }
}
