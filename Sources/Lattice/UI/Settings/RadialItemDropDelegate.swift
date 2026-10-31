import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialItemDropDelegate: DropDelegate {
    let target: RadialMenuItem
    @Binding var dragging: RadialMenuItem?
    let moveHandler: (RadialMenuItem, RadialMenuItem) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            moveHandler(dragging, target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

// MARK: - Editor sheet
