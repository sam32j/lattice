import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialDragCleanupDelegate: DropDelegate {
    @Binding var dragging: RadialMenuItem?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
