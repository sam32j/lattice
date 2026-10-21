// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum CaptureTimestampTests {
    static func run(_ suite: TestSuite) {
        let previous = L10n.shared.language
        defer { L10n.shared.language = previous }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        for (language, label) in [(AppLanguage.fr, "hier"), (.de, "gestern"), (.es, "ayer")] {
            L10n.shared.language = language
            suite.expect(Formatter.formattedCaptureTime(yesterday).lowercased().contains(label),
                         "capture timestamps use the selected app language for yesterday: \(language)")
        }
        let today = Date()
        let expected = DateFormatter()
        expected.locale = AppLanguage.ja.formattingLocale()
        expected.timeStyle = .short
        L10n.shared.language = .ja
        let actual = Formatter.formattedCaptureTime(today)
        suite.expect(actual == expected.string(from: today),
                     "today's capture time uses app language and clock preferences: \(actual), expected \(expected.string(from: today))")
    }
}
