// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Start the editor fade with the island resize. Retain outgoing controls
/// until their fade finishes so the closing silhouette cannot cut across them.
final class HubEditingPresentation: ObservableObject {
    @Published private(set) var isPresented = false
    @Published private(set) var isExpanded = false
    @Published private(set) var outgoingOptions: LatticeHubItem?
    @Published private(set) var optionsHeight: CGFloat = NotchLayout.hubOptionsHeight - 6
    private var generation = UUID()

    private var islandIsActive: Bool {
        let island = NotchService.shared
        return island.expanded && island.selected == .hub && !island.showingAppPanel && !island.showingSections
    }

    func setEditing(_ editing: Bool, options: LatticeHubItem?) {
        generation = UUID()
        let token = generation
        let motion: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? nil : .easeInOut(duration: 0.22)
        if editing {
            outgoingOptions = nil
            isPresented = true
            // The host can render synchronously while setting its bounds.
            // Start opacity after that layout, in the same turn as the resize.
            if islandIsActive { NotchService.shared.refreshPresentation() }
            withAnimation(motion) { isExpanded = true }
        } else {
            guard isPresented else { return }
            outgoingOptions = options
            withAnimation(motion, completionCriteria: .logicallyComplete) {
                isExpanded = false
            } completion: { [weak self] in
                guard let self, self.generation == token else { return }
                self.isPresented = false
                self.outgoingOptions = nil
                if self.islandIsActive { NotchService.shared.refreshPresentation() }
            }
        }
    }

    func reset() {
        generation = UUID()
        isExpanded = false
        isPresented = false
        outgoingOptions = nil
    }

    func measureOptions(_ height: CGFloat) {
        guard height.isFinite, height > 0, abs(optionsHeight - height) > 0.5 else { return }
        optionsHeight = height
    }
}
