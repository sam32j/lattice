import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialItemRow: View {
    let item: RadialMenuItem
    let text: RadialMenuFeatureStrings
    @Binding var dragging: RadialMenuItem?
    let edit: () -> Void
    let remove: () -> Void
    let openChildren: (() -> Void)?
    let moveHandler: (RadialMenuItem, RadialMenuItem) -> Void

    private var kindLabel: String {
        switch item.kind {
        case .app: return text.kindApp
        case .file: return text.kindFile
        case .url: return text.kindURL
        case .shortcut: return text.kindShortcut
        case .tool: return text.kindTool
        case .quickToggle: return FeatureStrings.quickToggles(L10n.shared.language).pageTitle
        case .windowLayout: return FeatureStrings.windowLayout(L10n.shared.language).title
        case .media: return text.kindMedia
        case .submenu: return text.kindSubmenu
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
            Button(action: edit) {
                HStack(spacing: 10) {
                    badge
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.displayName(text))
                        Text(kindLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let openChildren {
                Button(action: openChildren) {
                    HStack(spacing: 5) {
                        Text(text.editActionsButton)
                        Image(systemName: "chevron.forward")
                    }
                }
                .buttonStyle(.borderless)
                .help(text.editActionsButton)
            }
        }
        .opacity(dragging == item ? 0.45 : 1)
        .contentShape(Rectangle())
        .onDrag {
            dragging = item
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: RadialItemDropDelegate(target: item,
                                                                    dragging: $dragging,
                                                                    moveHandler: moveHandler))
        .contextMenu {
            Button(text.deleteButton, role: .destructive) {
                dragging = nil
                remove()
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if item.usesFileIcon {
            Image(nsImage: RadialMenuIconStore.fileIcon(for: item.payload))
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
                .frame(width: 30, height: 30)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.spaceGradient)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: item.effectiveSymbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
    }
}
