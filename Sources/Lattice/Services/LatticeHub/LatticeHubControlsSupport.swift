// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubService {
    var visibleControls: [HubControlAction] {
        let hidden = hiddenControlsSet
        return orderedControls.filter { $0.isAvailable && !hidden.contains($0) }
    }

    var hiddenControls: [HubControlAction] {
        let hidden = hiddenControlsSet
        return HubControlAction.allCases.filter { $0.isAvailable && hidden.contains($0) }
    }

    var hiddenControlsSet: Set<HubControlAction> {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.hubControlsHidden) ?? ""
        var hidden = Set(raw.split(separator: ",").compactMap { HubControlAction(rawValue: String($0)) })
        if QuickToolsSupport.hiddenIDs(from: hiddenItemsRaw).contains(HubControlAction.cameraPreview.rawValue) {
            hidden.insert(.cameraPreview)
        }
        return hidden
    }

    var orderedControls: [HubControlAction] {
        PanelLayout.itemOrder(HubControlAction.self, key: DefaultsKey.hubControlsOrder)
    }

    func setControlHidden(_ action: HubControlAction, _ hidden: Bool) {
        var ids = hiddenControlsSet
        if action == .cameraPreview {
            var legacy = QuickToolsSupport.hiddenIDs(from: hiddenItemsRaw)
            legacy.remove(action.rawValue)
            hiddenItemsRaw = QuickToolsSupport.serializeHiddenIDs(legacy)
            UserDefaults.standard.set(hiddenItemsRaw, forKey: DefaultsKey.quickLauncherHiddenItems)
        }
        if hidden {
            ids.insert(action)
        } else {
            ids.remove(action)
        }
        let serialized = ids.map(\.rawValue).sorted().joined(separator: ",")
        UserDefaults.standard.set(serialized, forKey: DefaultsKey.hubControlsHidden)
        self.objectWillChange.send()
    }

    /// Dynamic height for controls strip in the Dynamic Island
    var notchControlsHeight: CGFloat {
        let controls = visibleControls
        guard !controls.isEmpty else { return 0 }
        let rows = HubControlAction.rows(controls)
        return rows.first.isEmpty || rows.second.isEmpty ? 34 : 66
    }
}
