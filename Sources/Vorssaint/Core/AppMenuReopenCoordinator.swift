import Foundation

/// Recovery ordering is independent of AppKit windows, so an explicit Don't
/// show choice cannot be bypassed by an existing or recreated status item.
enum AppMenuReopenCoordinator {
    static func open(destination: @escaping () -> AppMenuDestination,
                     iconHidden: @escaping () -> Bool, iconVisible: @escaping () -> Bool,
                     recreateIcon: () -> Void, presentMenu: @escaping () -> Bool,
                     presentIsland: @escaping () -> Bool = { false },
                     openSettings: @escaping () -> Void,
                     schedule: (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        guard destination() != .none else { openSettings(); return }
        if destination() == .island {
            if !presentIsland() { openSettings() }
            return
        }
        if !iconHidden(), !iconVisible() { recreateIcon() }
        // Rebuilt status items have no settled screen frame until the next turn.
        schedule {
            guard destination() != .none else { openSettings(); return }
            if destination() == .island {
                if !presentIsland() { openSettings() }
                return
            }
            if iconVisible(), presentMenu() { return }
            openSettings()
        }
    }
}
