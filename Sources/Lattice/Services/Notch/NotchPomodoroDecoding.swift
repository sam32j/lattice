// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension NotchPomodoroConfiguration {
    private enum ConfigurationKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, longBreakInterval, totalSessions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: ConfigurationKeys.self)
        // Decode the original on-disk numbers verbatim for compatibility.
        // Whether they can safely resume is decided by the session cache's
        // validation (not by this lossless configuration decoder).
        self.init(rawFocusMinutes: try values.decode(Int.self, forKey: .focusMinutes),
                  rawShortBreakMinutes: try values.decode(Int.self, forKey: .shortBreakMinutes),
                  rawLongBreakMinutes: try values.decode(Int.self, forKey: .longBreakMinutes),
                  rawLongBreakInterval: try values.decode(Int.self, forKey: .longBreakInterval),
                  rawTotalSessions: try values.decode(Int.self, forKey: .totalSessions))
    }
}
