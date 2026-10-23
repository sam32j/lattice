import AppKit
import Combine

/// Owns presentation only. It never mutates File Cache items or cancels a job
/// merely because another mode becomes visible.
final class FileUtilityPresentation: ObservableObject {
    static let shared = FileUtilityPresentation()
    let session = FileUtilitySession.shared
    let model = MediaHUDModel.shared
    private var dragTimer: Timer?
    private var dragGeneration = UUID()
    private let optionIsHeld: () -> Bool
    init(optionIsHeld: @escaping () -> Bool = { NSEvent.modifierFlags.contains(.option) }) {
        self.optionIsHeld = optionIsHeld
    }
    var usesIsland: Bool {
        let location = MediaHUDLocation(rawValue: UserDefaults.standard.string(forKey: MediaHUDLocation.preferenceKey) ?? "") ?? .followFileCache
        return MediaHUDLocation.wantsIsland(location: location, cacheUsesIsland: NotchSupport.routesShelf(),
                                           islandAvailable: NotchSupport.showsFiles())
    }
    var holdsStandaloneOpen: Bool {
        session.effectiveMode == .optimizer || session.isDragging
    }
    var keepsStandaloneSurface: Bool {
        session.effectiveMode == .optimizer && AppFeature.mediaTools.isAvailable && !usesIsland
    }
    func select(_ mode: FileUtilityMode) {
        session.select(mode)
        if mode == .optimizer { openOptimizer() }
        else if ShelfService.shared.isVisible && !NotchSupport.routesShelf() {
            ShelfService.shared.presentSharedUtility(reposition: false)
        } else { ShelfService.shared.summon() }
    }
    func openOptimizer(inputs: [URL] = []) {
        guard AppFeature.mediaTools.isAvailable else { return }
        if !inputs.isEmpty { _ = model.receive(inputs) }
        session.select(.optimizer)
        if usesIsland, NotchService.shared.acceptsUserInteraction {
            ShelfService.shared.hide()
            NotchFileToolsService.shared.showHUD()
            NotchService.shared.open(.files)
        } else {
            NotchFileToolsService.shared.hideMedia()
            ShelfService.shared.presentSharedUtility(reposition: !ShelfService.shared.isVisible)
        }
    }
    func beginSharedDrag() {
        let shared = !NotchSupport.routesShelf() && !usesIsland
        session.beginDrag(sharedStandalone: shared, optimizerAvailable: AppFeature.mediaTools.isAvailable,
                          option: optionIsHeld())
        dragTimer?.invalidate(); dragGeneration = UUID()
        let generation = dragGeneration
        let timer = Timer(timeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self, self.session.isDragging, self.dragGeneration == generation else { timer.invalidate(); return }
            if NSEvent.pressedMouseButtons & 1 == 0 {
                timer.invalidate()
                // Native performDragOperation must commit before mouse-up clears
                // a transient preview. No file processing happens on this timer.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self, self.dragGeneration == generation else { return }
                    self.session.endDrag(); ShelfService.shared.refitSharedUtility()
                }
            } else {
                let before = self.session.effectiveMode
                self.session.updateDrag(option: self.optionIsHeld())
                if before != self.session.effectiveMode { ShelfService.shared.refitSharedUtility() }
            }
        }
        dragTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func canAccept(_ board: NSPasteboard) -> Bool {
        previewModifier()
        if session.effectiveMode == .optimizer {
            return AppFeature.mediaTools.isAvailable && !model.busy && MediaHUDPayload.urls(from: board) != nil
        }
        return !ShelfService.shared.isInternalDragActive && ShelfService.shared.canAcceptPasteboard(board)
    }
    func accept(_ sender: NSDraggingInfo) -> Bool {
        if session.resolveDrop(option: optionIsHeld()) == .optimizer {
            guard AppFeature.mediaTools.isAvailable, let urls = MediaHUDPayload.urls(from: sender.draggingPasteboard),
                  model.receive(urls) else { return false }
            session.commitDrop()
            ShelfService.shared.refitSharedUtility()
            return true
        }
        let accepted = ShelfService.shared.accept(draggingInfo: sender)
        if accepted { session.commitDrop() }
        return accepted
    }
    func previewModifier() {
        session.updateDrag(option: optionIsHeld())
    }
    func syncWithPreferences() {
        if AppFeature.mediaTools.isAvailable {
            if NotchFileToolsService.shared.usesHUD, NotchFileToolsService.shared.mediaPresented,
               !NotchSupport.showsFiles() {
                NotchFileToolsService.shared.hideMedia()
                session.select(.optimizer)
                ShelfService.shared.presentSharedUtility(reposition: !ShelfService.shared.isVisible)
            }
            return
        }
        model.cancel(); MediaHUDDialogs.cancelActiveDialog()
        session.endDrag(); dragTimer?.invalidate(); dragTimer = nil
        if session.mode == .optimizer {
            session.select(.cache)
            if !AppFeature.shelf.isAvailable { ShelfService.shared.hide() }
        }
    }
}
