// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    func chooseExceptionApp() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = text.addException
        guard !inNotch else {
            DispatchQueue.main.async {
                guard panel.runAboveIsland() == .OK, let url = panel.url else { return }
                updates.addExclusion(appAt: url)
            }
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        updates.addExclusion(appAt: url)
    }

    @ViewBuilder
    var compactList: some View {
        let rows = LazyVStack(alignment: .leading, spacing: Self.compactRowSpacing) {
            ForEach(updates.items) { item in
                row(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        ScrollView { rows }
            .frame(height: Self.compactHeight(rowCount: updates.items.count))
    }

    static let compactRowHeight: CGFloat = 40
    static let compactRowSpacing: CGFloat = 5
    static let compactVisibleRows = 4

    static func compactHeight(rowCount: Int) -> CGFloat {
        let visible = min(max(rowCount, 1), compactVisibleRows)
        return CGFloat(visible) * compactRowHeight
            + CGFloat(visible - 1) * compactRowSpacing
    }

    static func compactUtilityHeight(itemCount: Int) -> CGFloat {
        if itemCount == 0 { return 148 }
        return min(290, 85 + compactHeight(rowCount: itemCount))
    }
}
