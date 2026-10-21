// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum RadialProfileSyncTests {
    class State {
        let defaults: UserDefaults
        var profiles: [RadialMenuProfile] = []
        var selectedProfileID: UUID?
        var lastSyncedProfilesData: Data?
        init(_ defaults: UserDefaults) { self.defaults = defaults }
    }
    struct RadialMenuService {
        static let shared = RadialMenuService()
        func syncWithPreferences() {}
    }
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.radial-profile-sync.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let editor = Editor(defaults)
        let profile = RadialMenuProfile(name: "My ")
        editor.profiles = [profile]
        editor.selectedProfileID = profile.id
        editor.persist()
        editor.refreshProfilesFromDefaults()
        suite.expect(editor.profiles.first?.name == "My ",
                     "a profile save notification preserves a space while typing the next word")
        defaults.set(true, forKey: "unrelated-setting")
        editor.refreshProfilesFromDefaults()
        suite.expect(editor.profiles.first?.name == "My ",
                     "unrelated defaults writes preserve an unfinished profile edit")
        var external = profile
        external.name = "External name"
        external.shortcut = GlobalShortcut.radialMenuDefault.storageValue
        defaults.set(RadialMenuSupport.encodeProfiles([external]), forKey: DefaultsKey.radialMenuProfiles)
        editor.refreshProfilesFromDefaults()
        suite.expect(editor.profiles.first?.name == "External name"
                     && editor.profiles.first?.shortcut == external.shortcut
                     && editor.selectedProfileID == profile.id,
                     "an external profile edit updates the editor without changing selection")
    }
}
