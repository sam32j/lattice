import SwiftUI

struct FileUtilityStandaloneView: View {
    @ObservedObject private var session = FileUtilitySession.shared
    @ObservedObject private var model = MediaHUDModel.shared
    @ObservedObject private var features = FeatureRuntime.shared
    var body: some View {
        VStack(spacing: 0) {
            FileUtilityModeBar(selected: session.effectiveMode,
                cacheAvailable: features.isAvailable(.shelf), optimizerAvailable: features.isAvailable(.mediaTools),
                showOptionHint: features.isAvailable(.shelf) && features.isAvailable(.mediaTools)
                    && !NotchSupport.routesShelf() && !FileUtilityPresentation.shared.usesIsland,
                select: FileUtilityPresentation.shared.select)
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)
            if session.effectiveMode == .optimizer {
                MediaHUDView(model: model, onClose: { ShelfService.shared.hide() }, onHeight: { _ in
                    ShelfService.shared.refitSharedUtility()
                }, onDropCommitted: { FileUtilitySession.shared.commitDrop() },
                   canReceiveDrop: FileUtilityPresentation.shared.canAccept,
                   receiveDrop: FileUtilityPresentation.shared.accept)
            } else {
                ShelfView(embeddedInSharedSurface: true).environmentObject(ShelfService.shared)
            }
        }
        .frame(width: session.effectiveMode == .optimizer ? 350 : 304)
        .background(HUDBackdrop(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.secondary.opacity(0.2)))
        .onChange(of: session.effectiveMode) { ShelfService.shared.refitSharedUtility() }
    }
}
