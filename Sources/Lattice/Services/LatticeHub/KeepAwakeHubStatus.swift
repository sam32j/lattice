// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Shared spoken status, independent of live services so every state can be verified.
enum KeepAwakeHubStatus {
    static func text(active: Bool, failed: Bool, paused: Bool, end: Date?, sessionMinutes: Int?,
                     now: Date, language: AppLanguage, calendar: Calendar = .current) -> String {
        let text = FeatureStrings.keepAwakeHub(language)
        let strings = Strings.localized(language)
        let locale = language.formattingLocale()
        if failed { return text.updateFailed }
        if paused { return text.paused }
        guard active else { return text.off }
        guard let end else { return strings.keepAwakeUntilDisabled }
        if sessionMinutes == nil {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = calendar.isDate(end, inSameDayAs: now) ? .none : .medium
            formatter.timeStyle = .short
            return String(format: text.onUntil, formatter.string(from: end))
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        var localizedCalendar = calendar
        localizedCalendar.locale = locale
        formatter.calendar = localizedCalendar
        let duration = max(60, ceil(end.timeIntervalSince(now) / 60) * 60)
        return "\(strings.keepAwakeEndsIn) \(formatter.string(from: duration) ?? "")"
    }
}
