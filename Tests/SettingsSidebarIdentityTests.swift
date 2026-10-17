// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum SettingsSidebarIdentityTests {
    class State {
        static let toolOnlyPages: Set<SettingsPage> = [.energy, .mouse, .quickTools]
        static func sections(_ s: Strings, language: AppLanguage, superKeySource: SuperKeySource)
            -> [(title: String, items: [SettingsDirectoryItem])] {
            let pages: [[SettingsPage]] = [
                [.general, .features, .energy], [.mouse], [.clipboard], [.cleaner],
                [.quickTools], [.screenshot, .screenRecorder], [.shortcuts],
            ]
            return pages.enumerated().map { index, pages in
                ("Group \(index)", pages.map { SettingsDirectoryItem(page: $0, title: "Page", icon: "gear") })
            }
        }
    }
    static func run(_ suite: TestSuite) {
        let sections = Directory.sidebarSections(.enUS, language: .enUS, isAvailable: { _ in true })
        suite.expect(sections.count == Set(sections.map(\.id)).count,
                     "synthetic sidebar categories never collide with enumerated app or capture groups")
        suite.expect(sections.contains { $0.id == 6 } && sections.contains { $0.id == 1006 },
                     "app settings and sound keep independent collapse identities")
    }
}
