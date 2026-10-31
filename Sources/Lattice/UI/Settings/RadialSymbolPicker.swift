import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialSymbolPicker: View {
    let text: RadialMenuFeatureStrings
    @Binding var item: RadialMenuItem

    private static let symbols = RadialMenuSupport.symbolNames.filter {
        NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil
    }

    private let columns = [GridItem(.adaptive(minimum: 34), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.iconLabel)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                iconButton(symbol: nil)
                ForEach(Self.symbols, id: \.self) { symbol in
                    iconButton(symbol: symbol)
                }
            }
        }
    }

    @ViewBuilder
    private func iconButton(symbol: String?) -> some View {
        let selected = symbol == nil ? item.symbolName.isEmpty : item.symbolName == symbol
        Button {
            item.symbolName = symbol ?? ""
        } label: {
            Group {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                } else if item.kind == .app || item.kind == .file, !item.payload.isEmpty {
                    Image(nsImage: RadialMenuIconStore.fileIcon(for: item.payload))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                } else if let customImage = RadialMenuIconStore.customIcon(for: item) {
                    Image(nsImage: customImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: item.defaultSymbolName)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(width: 34, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.13),
                                  lineWidth: selected ? 1.2 : 1)
            )
        }
        .buttonStyle(.plain)
        .help(symbol ?? text.automaticLabel)
    }

}
