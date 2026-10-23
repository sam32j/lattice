import AppKit

final class KeyableShelfPanel: OverlayPanel, NSDraggingDestination {
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepts = self === ShelfService.shared.panel
            ? FileUtilityPresentation.shared.canAccept(sender.draggingPasteboard)
            : (!ShelfService.shared.isInternalDragActive && ShelfService.shared.canAcceptPasteboard(sender.draggingPasteboard))
        ShelfService.shared.setDropTargeted(accepts)
        return accepts ? .copy : []
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }

    func draggingExited(_ sender: NSDraggingInfo?) { ShelfService.shared.setDropTargeted(false) }

    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { draggingEntered(sender) != [] }

    func concludeDragOperation(_ sender: NSDraggingInfo?) { ShelfService.shared.setDropTargeted(false) }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { ShelfService.shared.setDropTargeted(false) }
        return self === ShelfService.shared.panel ? FileUtilityPresentation.shared.accept(sender)
            : ShelfService.shared.accept(draggingInfo: sender)
    }

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if self === ShelfService.shared.panel, FileUtilitySession.shared.effectiveMode == .optimizer {
            return super.performKeyEquivalent(with: event)
        }
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        if ShelfSelectionSupport.isClearSelectionShortcut(
            keyCode: event.keyCode,
            hasSelectionModifiers: !modifiers.isEmpty
        ) {
            ShelfService.shared.clearSelection()
            return true
        }
        if modifiers == [.command], event.charactersIgnoringModifiers?.lowercased() == "a" {
            ShelfService.shared.selectAllVisibleItems()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        if self === ShelfService.shared.panel, FileUtilitySession.shared.effectiveMode == .optimizer {
            ShelfService.shared.hide(); return
        }
        ShelfService.shared.clearSelection()
    }
}
