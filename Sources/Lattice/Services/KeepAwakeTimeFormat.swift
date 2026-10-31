// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Shared compact reading for Stay Awake's Hub and island surfaces.
enum KeepAwakeTimeFormat {
    static func compact(end: Date?, now: Date, locale: Locale = .current) -> String {
        guard let end else { return "∞" }
        let remaining = end.timeIntervalSince(now)
        guard remaining.isFinite else { return "1′" }
        if remaining <= 180 * 60 {
            return "\(max(1, Int(ceil(max(0, remaining) / 60))))′"
        }
        let quarters = Int(min(Double(Int32.max), (remaining / (15 * 60)).rounded()))
        let fraction = ["", "¼", "½", "¾"][quarters % 4]
        return "\(quarters / 4)\(fraction)\(hourUnit(locale: locale))"
    }

    static func hourUnit(locale: Locale) -> String {
        // Keep the explicitly requested English compact spelling.
        if locale.language.languageCode?.identifier == "en" { return "hr" }
        return unit(.hours, locale: locale)
    }

    static func unit(_ unit: UnitDuration, locale: Locale) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitStyle = .short
        formatter.unitOptions = .providedUnit
        return formatter.string(from: unit)
    }

    static func increment(minutes: Int, locale: Locale) -> String {
        let value = minutes < 60 ? minutes : minutes / 60
        let unit = minutes < 60 ? unit(.minutes, locale: locale) : hourUnit(locale: locale)
        return "+\(value)\(unit)"
    }
}
