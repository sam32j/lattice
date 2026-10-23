import SwiftUI

struct MediaSettings: View {
    @AppStorage(MediaHUDLocation.preferenceKey) private var location = MediaHUDLocation.followFileCache.rawValue
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCard {
                    SettingsControlRow(title: "Show Media Optimizer in") {
                        Picker("Show Media Optimizer in", selection: $location) {
                            ForEach(MediaHUDLocation.allCases) { Text($0.title).tag($0.rawValue) }
                        }.labelsHidden().pickerStyle(.menu)
                            .onChange(of: location) {
                                if FileUtilitySession.shared.effectiveMode == .optimizer,
                                   ShelfService.shared.isVisible || NotchFileToolsService.shared.mediaPresented {
                                    FileUtilityPresentation.shared.openOptimizer()
                                }
                            }
                    }
                    Text("Dynamic Island uses its File Cache widget. If it isn't available, the optimizer opens in a standalone window.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack {
                        Text("Drop files to optimize copies beside the originals.").font(.callout)
                        Spacer()
                        Button("Open optimizer") { FileUtilityPresentation.shared.openOptimizer() }
                    }
                    Text("When both utilities use standalone windows, shake a dragged file to open File Cache, then hold Option to switch that same window to Media Optimizer.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                MediaWorkspaceView(compact: false)
            }.padding(22)
        }
    }
}
