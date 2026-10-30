// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension NotchPomodoroConfiguration {
    private enum ConfigurationKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, longBreakInterval, totalSessions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: ConfigurationKeys.self)
        self.init(focusMinutes: try values.decode(Int.self, forKey: .focusMinutes),
                  shortBreakMinutes: try values.decode(Int.self, forKey: .shortBreakMinutes),
                  longBreakMinutes: try values.decode(Int.self, forKey: .longBreakMinutes),
                  longBreakInterval: try values.decode(Int.self, forKey: .longBreakInterval),
                  totalSessions: try values.decode(Int.self, forKey: .totalSessions))
    }
}
