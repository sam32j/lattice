// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

extension LatticeHubService {
    /// Include hidden and unavailable entries so one drag cannot reset their
    /// saved positions. A no-op drop never writes preferences.
    func moveTool(_ source: LatticeHubItem, relativeTo target: LatticeHubItem, after: Bool) {
        guard isEditing, source != target,
              visibleItems.contains(source), visibleItems.contains(target) else { return }
        let previous = PanelLayout.itemOrder(LatticeHubItem.self, key: DefaultsKey.quickLauncherItemOrder)
        var next = previous
        guard let from = next.firstIndex(of: source) else { return }
        next.remove(at: from)
        guard let targetIndex = next.firstIndex(of: target) else { return }
        next.insert(source, at: targetIndex + (after ? 1 : 0))
        guard next != previous else { return }
        PanelLayout.setItemOrder(next, key: DefaultsKey.quickLauncherItemOrder)
        objectWillChange.send()
    }
}
