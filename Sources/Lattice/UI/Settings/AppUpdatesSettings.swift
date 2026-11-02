// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct AppUpdatesSettings: View {
    @ObservedObject private var updates = AppUpdatesService.shared

    var body: some View {
        AppUpdatesListView()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear { updates.checkIfNeeded() }
    }
}
