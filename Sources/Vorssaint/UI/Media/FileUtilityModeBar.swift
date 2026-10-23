import SwiftUI

struct FileUtilityModeBar: View {
    let selected: FileUtilityMode
    var cacheAvailable = true
    var optimizerAvailable = true
    var showOptionHint = false
    let select: (FileUtilityMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(FileUtilityMode.allCases) { mode in
                    Button { select(mode) } label: {
                        Label(mode == .cache ? "File Cache" : "Optimize",
                              systemImage: mode == .cache ? "tray.full" : "wand.and.stars")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selected == mode ? Color.accentColor : Color.secondary)
                            .background(selected == mode ? Color.accentColor.opacity(0.13) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .disabled(mode == .cache ? !cacheAvailable : !optimizerAvailable)
                    .accessibilityAddTraits(selected == mode ? .isSelected : [])
                }
            }
            if showOptionHint {
                Text("Drag and shake, then hold ⌥ to optimize.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
