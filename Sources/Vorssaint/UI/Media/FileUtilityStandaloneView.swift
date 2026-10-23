import SwiftUI

struct FileUtilityStandaloneView: View {
    @ObservedObject private var session = FileUtilitySession.shared
    @ObservedObject private var model = MediaHUDModel.shared
    @ObservedObject private var features = FeatureRuntime.shared
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(FileUtilityMode.allCases) { mode in
                    Button(mode == .cache ? "File Cache" : "Optimize") { FileUtilityPresentation.shared.select(mode) }
                        .buttonStyle(.bordered)
                        .tint(session.effectiveMode == mode ? Color.accentColor : nil)
                        .disabled(mode == .cache ? !features.isAvailable(.shelf) : !features.isAvailable(.mediaTools))
                }
                Spacer(minLength: 0)
                Text("⌥").font(.caption).foregroundStyle(.secondary)
                    .help("While dragging after a shake, hold Option to optimize instead of caching.")
            }.padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)
            if session.effectiveMode == .optimizer {
                MediaHUDView(model: model, onClose: { ShelfService.shared.hide() }, onHeight: { _ in
                    ShelfService.shared.refitSharedUtility()
                }, onDropCommitted: { FileUtilitySession.shared.commitDrop() },
                   canReceiveDrop: FileUtilityPresentation.shared.canAccept,
                   receiveDrop: FileUtilityPresentation.shared.accept)
            } else {
                ShelfView().environmentObject(ShelfService.shared)
            }
        }
        .frame(width: session.effectiveMode == .optimizer ? 350 : 304)
        .background(HUDBackdrop(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.secondary.opacity(0.2)))
        .onChange(of: session.effectiveMode) { ShelfService.shared.refitSharedUtility() }
    }
}
