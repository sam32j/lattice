import Foundation

/// A permission result belongs to the profile that was being edited, not its old array index.
enum RadialProfileActivation {
    static func index(requestedID: UUID, selectedID: UUID, enabled: Bool,
                      profiles: [RadialMenuProfile]) -> Int? {
        guard enabled, requestedID == selectedID else { return nil }
        return profiles.firstIndex { $0.id == requestedID }
    }
}
