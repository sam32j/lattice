import AppKit
import SwiftUI

extension ShelfService {
    func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = KeyableShelfPanel(contentRect: .zero,
                                      styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.becomesKeyOnlyIfNeeded = true
        panel.registerForDraggedTypes(Self.tileDropTypes)
        panel.hasShadow = false
        // Not movable by background: dragging a tile must start an item drag,
        // not move the whole panel.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingController(rootView: FileUtilityStandaloneView())
        host.sizingOptions = .preferredContentSize
        panel.contentViewController = host
        self.panel = panel
        return panel
    }

    /// Bring the classic shelf to the cursor without changing its shortcut.
    /// The docked shelf steps aside until this shared panel closes.
    func summon() {
        guard AppFeature.shelf.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.shelfEnabled) else { return }
        FileUtilitySession.shared.select(.cache)
        if NotchService.shared.openShelf() { return }
        presentSharedUtility()
    }

    func summonFromDrag() {
        guard AppFeature.shelf.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.shelfEnabled) else { return }
        if NotchSupport.routesShelf() { summon(); return }
        FileUtilityPresentation.shared.beginSharedDrag()
        presentSharedUtility()
    }

    func presentSharedUtility(reposition: Bool = true) {
        let panel = ensurePanel()
        cancelAutoHide()
        if reposition { position(panel) } else { refitSharedUtility() }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        updatePointerInsidePanel()
        scheduleAutoHideIfIdle()
        scheduleDockedSync()
    }

    func refitSharedUtility() {
        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.panel, panel.isVisible, let view = panel.contentViewController?.view else { return }
            view.layoutSubtreeIfNeeded()
            let size = view.fittingSize
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
            let screen = NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) }?.visibleFrame ?? NSScreen.pointerVisibleFrame
            let x = min(max(screen.minX + 8, panel.frame.minX), screen.maxX - size.width - 8)
            let y = min(max(screen.minY + 8, panel.frame.maxY - size.height), screen.maxY - size.height - 8)
            let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
            if panel.frame != frame { panel.setFrame(frame, display: true) }
        }
    }
}
