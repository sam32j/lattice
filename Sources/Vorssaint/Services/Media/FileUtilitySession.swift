import Combine
import Foundation

enum FileUtilityMode: String, CaseIterable, Identifiable {
    case cache, optimizer
    var id: Self { self }
    var title: String { self == .cache ? "File Cache" : "Media Optimizer" }
}

/// Transient Option preview is separate from the mode committed by a drop.
final class FileUtilitySession: ObservableObject {
    static let shared = FileUtilitySession()
    @Published private(set) var mode: FileUtilityMode = .cache
    @Published private(set) var preview: FileUtilityMode?
    private(set) var isDragging = false
    private var mayAlternate = false
    var effectiveMode: FileUtilityMode { preview ?? mode }
    func select(_ mode: FileUtilityMode) {
        self.mode = mode; preview = nil; isDragging = false; mayAlternate = false
    }
    func beginDrag(sharedStandalone: Bool, optimizerAvailable: Bool, option: Bool) {
        mode = .cache
        isDragging = true
        mayAlternate = sharedStandalone && optimizerAvailable
        updateDrag(option: option)
    }
    func updateDrag(option: Bool) {
        guard isDragging else { return }
        preview = mayAlternate && option ? .optimizer : nil
    }
    func commitDrop() {
        mode = effectiveMode
        endDrag()
    }
    func resolveDrop(option: Bool) -> FileUtilityMode {
        updateDrag(option: option)
        return effectiveMode
    }
    func endDrag() { isDragging = false; preview = nil; mayAlternate = false }
}
