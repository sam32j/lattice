// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct UpdateSettingsStatusRow<Status: View, Actions: View>: View {
    let status: Status
    let actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            status.layoutPriority(-1)
            Spacer(minLength: 4)
            actions.fixedSize(horizontal: true, vertical: false)
        }
    }
}
