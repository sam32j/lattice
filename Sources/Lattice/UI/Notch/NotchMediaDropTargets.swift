// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One drop layout shared by Files and editor-only installations.
struct NotchMediaDropTargets: View {
    let canDropOnShelf: Bool
    let optimizationDropAvailable: Bool
    let editorDropAvailable: Bool
    let optimizationAvailable: Bool
    let targetsMediaDrop: Bool
    let targetsEditorDrop: Bool
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: NotchFileToolsSupport.dropSpacing) {
            target(FeatureStrings.notch(l10n.language).files, symbol: "tray.full",
                   selected: !targetsMediaDrop && !targetsEditorDrop,
                   available: canDropOnShelf)
            VStack(spacing: NotchFileToolsSupport.dropSpacing) {
                if optimizationDropAvailable {
                    target(FeatureStrings.notchFiles(l10n.language).optimizeMedia, symbol: "wand.and.stars",
                           selected: targetsMediaDrop, available: optimizationAvailable)
                }
                if editorDropAvailable {
                    target(MediaEditorFileStrings.openInEditor, symbol: "pencil.and.outline",
                           selected: targetsEditorDrop, available: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func target(_ title: String, symbol: String, selected: Bool, available: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 22, weight: .light))
            Text(title).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(selected ? 0.14 : 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(selected ? 0.7 : 0.2),
                                                                  lineWidth: selected ? 1.5 : 0.75) }
        .opacity(available ? 1 : 0.35)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension NotchMediaDropTargets {
    init(service: NotchService) {
        self.init(canDropOnShelf: service.canDropOnShelf,
                  optimizationDropAvailable: service.optimizationDropAvailable,
                  editorDropAvailable: service.editorDropAvailable,
                  optimizationAvailable: service.optimizationDropAvailable && NotchFileToolsService.shared.canAcceptMediaDrop,
                  targetsMediaDrop: service.targetsMediaDrop, targetsEditorDrop: service.targetsEditorDrop)
    }
}
