import Foundation

enum MediaHUDLocation: String, CaseIterable, Identifiable {
    case followFileCache, window, island
    static let preferenceKey = "mediaOptimizerPresentation"
    var id: Self { self }
    var title: String {
        switch self {
        case .followFileCache: return "Follow File Cache"
        case .window: return "Standalone window"
        case .island: return "Dynamic Island"
        }
    }
    static func wantsIsland(location: Self, cacheUsesIsland: Bool, islandAvailable: Bool) -> Bool {
        islandAvailable && (location == .island || (location == .followFileCache && cacheUsesIsland))
    }
}
