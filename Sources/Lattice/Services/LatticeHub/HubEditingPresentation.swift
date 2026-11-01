// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The island first makes room, then opens the editor. Closing reverses that
/// sequence, so its silhouette never cuts across outgoing editing controls.
final class HubEditingPresentation: ObservableObject {
    @Published private(set) var isPresented = false
    @Published private(set) var isExpanded = false
    @Published private(set) var outgoingOptions: LatticeHubItem?
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
            let reveal = { [weak self] in
                guard let self, self.generation == token, self.isPresented else { return }
                withAnimation(motion) { self.isExpanded = true }
            }
            if islandIsActive {
                NotchService.shared.refreshPresentation()
                NotchService.shared.perform(collapsing: false, reveal)
            } else { reveal() }
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
}
