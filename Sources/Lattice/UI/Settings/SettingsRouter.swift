import Combine
import Foundation

/// Whether the Settings window can be seen. Closing it keeps the window and
/// its last page alive, so a page that animates on its own pauses on this
/// instead of drawing for nobody until the app quits. Kept apart from the
/// router so a covered or reopened window does not redraw every page.
final class SettingsWindowVisibility: ObservableObject {
    static let shared = SettingsWindowVisibility()
    @Published private(set) var isVisible = false

    func set(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
    }
}

/// Selects a Settings destination and publishes a fresh request identity even
/// when callers ask for the same page and anchor repeatedly.
final class SettingsRouter: ObservableObject {
    static let shared = SettingsRouter()

    private struct HistoryEntry {
        let destination: FeatureSettingsDestination
        let sidebarFeature: AppFeature?
    }

    @Published var page: SettingsPage = .general {
        didSet {
            if page == .features { page = .general }
            guard page != oldValue else { return }
            destination = FeatureSettingsDestination(page)
            sidebarFeature = nil
            pendingDestinationRequest = nil
            pendingFeatureTarget = nil
            if !isTraversingHistory {
                history.removeSubrange((historyIndex + 1)..<history.count)
                history.append(HistoryEntry(destination: destination, sidebarFeature: nil))
                historyIndex += 1
            }
        }
    }
    @Published private(set) var destination = FeatureSettingsDestination(.general)
    @Published private(set) var sidebarFeature: AppFeature?
    @Published private(set) var requestID = UUID()
    @Published private(set) var pendingDestinationRequest: SettingsDestinationRequest?
    /// One-shot hint for the Features hub: which feature row to reveal once
    /// the requested page lands. Always set (to nil when no target is given)
    /// on every `request`, so a stale target from an earlier search can never
    /// leak into a later, unrelated navigation.
    @Published private(set) var pendingFeatureTarget: SettingsFeatureTargetRequest?
    /// One-shot hint for the Cleaner page's tool switcher, so a panel surface
    /// can land directly on a specific tool. Consumed and cleared on arrival.
    /// One-shot hint for the Dynamic Island page, so a section of the island
    /// can open its own options. Consumed and cleared on arrival.
    @Published var notchModule: NotchModule?
    @Published var notchSettingsTab: String?
    /// One-shot hint for the Dynamic Island page to show the companion's content page,
    /// where its settings live. Consumed and cleared on arrival.
    @Published var notchCompanion = false
    /// One-shot hint for the Video Downloader page to scroll to a specific section.
    @Published var videoDownloaderSection: String?

    private var history = [HistoryEntry(destination: FeatureSettingsDestination(.general),
                                        sidebarFeature: nil)]
    private var historyIndex = 0
    private var isTraversingHistory = false

    init() {}

    /// `replacingVisit` swaps what the current visit shows without adding a
    /// history entry, for a fallback when the visited tool went away.
    func request(_ destination: FeatureSettingsDestination, targetFeature: AppFeature? = nil,
                 sidebarFeature: AppFeature? = nil, replacingVisit: Bool = false) {
        if destination.page == .features {
            request(targetFeature?.settingsDestination ?? FeatureSettingsDestination(.general),
                    sidebarFeature: targetFeature, replacingVisit: replacingVisit)
            return
        }
        // The companion's settings are a content destination of the Dynamic Island page.
        if destination.page == .notchMascot {
            request(FeatureSettingsDestination(.notch), targetFeature: targetFeature,
                    sidebarFeature: sidebarFeature, replacingVisit: replacingVisit)
            notchCompanion = true
            return
        }
        // Any other request, history included, drops a hint nobody took.
        notchCompanion = false
        notchSettingsTab = nil
        let requestID = UUID()
        let samePage = page == destination.page
        page = destination.page
        self.destination = destination
        self.sidebarFeature = sidebarFeature?.settingsDestination == destination ? sidebarFeature : nil
        let entry = HistoryEntry(destination: destination, sidebarFeature: self.sidebarFeature)
        // Section requests refine the current page visit, not a new history
        // entry. General and Energy show one tool per anchor, so switching
        // tools there is a visit of its own.
        if samePage && !isTraversingHistory && !replacingVisit
            && Self.anchorSelectsTool(on: destination.page)
            && history[historyIndex].destination != destination {
            history.removeSubrange((historyIndex + 1)..<history.count)
            history.append(entry)
            historyIndex += 1
        } else {
            history[historyIndex] = entry
        }
        pendingDestinationRequest = SettingsDestinationRequest(id: requestID,
                                                               destination: destination)
        pendingFeatureTarget = targetFeature.map {
            SettingsFeatureTargetRequest(id: requestID, feature: $0)
        }
        self.requestID = requestID
    }

    private static func anchorSelectsTool(on page: SettingsPage) -> Bool {
        page == .general || page == .energy
    }

    func goBack(isPageVisible: (SettingsPage) -> Bool = { _ in true }) {
        navigateHistory(step: -1, isPageVisible: isPageVisible)
    }

    func goForward(isPageVisible: (SettingsPage) -> Bool = { _ in true }) {
        navigateHistory(step: 1, isPageVisible: isPageVisible)
    }

    func canGoBack(isPageVisible: (SettingsPage) -> Bool = { _ in true }) -> Bool {
        historyTarget(step: -1, isPageVisible: isPageVisible) != nil
    }

    func canGoForward(isPageVisible: (SettingsPage) -> Bool = { _ in true }) -> Bool {
        historyTarget(step: 1, isPageVisible: isPageVisible) != nil
    }

    private func navigateHistory(step: Int, isPageVisible: (SettingsPage) -> Bool) {
        guard let index = historyTarget(step: step, isPageVisible: isPageVisible) else { return }
        historyIndex = index
        isTraversingHistory = true
        notchModule = nil
        let entry = history[index]
        request(entry.destination, sidebarFeature: entry.sidebarFeature)
        isTraversingHistory = false
    }

    private func historyTarget(step: Int, isPageVisible: (SettingsPage) -> Bool) -> Int? {
        var index = historyIndex + step
        while history.indices.contains(index) {
            if isPageVisible(history[index].destination.page) { return index }
            index += step
        }
        return nil
    }

    /// Clears only the request a view actually handled. A newer request that
    /// arrived while the destination page was being installed must survive.
    func consumeDestinationRequest(id: UUID) {
        guard pendingDestinationRequest?.id == id else { return }
        pendingDestinationRequest = nil
    }

    /// Clears only the feature target a view actually revealed. Mirrors
    /// `consumeDestinationRequest`: a newer request that arrived while the
    /// Features hub was still laying out must survive.
    func consumeFeatureTarget(id: UUID) {
        guard pendingFeatureTarget?.id == id else { return }
        pendingFeatureTarget = nil
    }
}
