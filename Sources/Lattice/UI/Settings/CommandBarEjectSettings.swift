// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct CommandBarEjectSettings: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let strings = FeatureStrings.quickToggles(l10n.language)
        if AppFeature.commandBar.isAvailable {
            Section {
                DiskExclusionsList()
            } header: {
                Label(strings.ejectTitle, systemImage: "eject")
            } footer: {
                Text(strings.ejectCaption)
            }
        }
    }
}
