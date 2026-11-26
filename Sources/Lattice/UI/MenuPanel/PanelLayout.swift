// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

protocol PanelOrderItem: RawRepresentable, CaseIterable, Hashable where RawValue == String {}

/// Persisted item ordering support used across Lattice Hub and settings.
enum PanelLayout {
    private static var defaults: UserDefaults { .standard }

    static func itemOrder<Item: PanelOrderItem>(_ type: Item.Type, key: String) -> [Item] {
        let defaultOrder = type.allCases.map(\.rawValue)
        let raw = defaults.string(forKey: key) ?? ""
        return Defaults.sanitizedPanelItemOrder(raw, defaultOrder: defaultOrder).compactMap(Item.init(rawValue:))
    }

    static func setItemOrder<Item: PanelOrderItem>(_ ids: [Item], key: String) {
        defaults.set(ids.map(\.rawValue).joined(separator: ","), forKey: key)
    }
}

struct PanelReorderableItem<Item: PanelOrderItem, Content: View>: View {
    let item: Item
    var isEnabled = true
    var cornerRadius: CGFloat = 10
    @Binding var order: [Item]
    @Binding var dragging: Item?
    let content: () -> Content

    var body: some View {
        if isEnabled {
            content()
                // Only the outlined gap stays behind while dragging, so the
                // landing preview and the row never show twice.
                .opacity(dragging == item ? 0 : 1.0)
                .overlay {
                    if dragging == item {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .onDrag(itemProvider)
                .onDrop(of: [UTType.text], delegate: PanelItemDropDelegate(item: item,
                                                                           order: $order,
                                                                           dragging: $dragging))
        } else {
            content()
        }
    }

    private func itemProvider() -> NSItemProvider {
        dragging = item
        let provider = NSItemProvider(object: item.rawValue as NSString)
        // Marks the drag as a reorder, so the Shelf and the island's drop
        // area leave it alone instead of offering to keep the text.
        provider.registerDataRepresentation(forTypeIdentifier: ShelfPasteboardSupport.reorderDragType,
                                            visibility: .all) { completion in
            completion(Data(), nil)
            return nil
        }
        return provider
    }
}

private struct PanelItemDropDelegate<Item: PanelOrderItem>: DropDelegate {
    let item: Item
    @Binding var order: [Item]
    @Binding var dragging: Item?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item,
              let from = order.firstIndex(of: dragging),
              let to = order.firstIndex(of: item) else { return }
        if from != to {
            withAnimation(.easeInOut(duration: 0.18)) {
                order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
