// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension NotchPomodoroConfiguration {
    private enum ConfigurationKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, longBreakInterval, totalSessions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: ConfigurationKeys.self)
        let focus = try values.decode(Int.self, forKey: .focusMinutes)
        let shortBreak = try values.decode(Int.self, forKey: .shortBreakMinutes)
        let longBreak = try values.decode(Int.self, forKey: .longBreakMinutes)
        let interval = try values.decode(Int.self, forKey: .longBreakInterval)
        let sessions = try values.decode(Int.self, forKey: .totalSessions)
        // Accept the complete legacy ranges, not only today's preset choices.
        // Corrupt cached values must never skip a restored Pomodoro phase.
        guard (1...180).contains(focus), (1...60).contains(shortBreak),
              (1...60).contains(longBreak), (0...24).contains(interval),
              (1...24).contains(sessions) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid persisted Pomodoro configuration"))
        }
        self.init(rawFocusMinutes: focus, rawShortBreakMinutes: shortBreak,
                  rawLongBreakMinutes: longBreak, rawLongBreakInterval: interval,
                  rawTotalSessions: sessions)
    }
}
