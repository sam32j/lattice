import Foundation

/// Presentation only: never deletes saved priority entries.
enum AudioPriorityPresentation {
    static func visibleUIDs(_ uids: [String], isAvailable: (String) -> Bool,
                            displayName: (String) -> String?) -> [String] {
        uids.filter { uid in
            if isAvailable(uid) { return true }
            guard let name = displayName(uid)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty, name != uid else { return false }
            let uuidPrefix = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?:-|$)"#
            let macPrefix = #"^[0-9a-f]{2}(?::[0-9a-f]{2}){5}(?:-|$)"#
            return name.range(of: uuidPrefix, options: [.regularExpression, .caseInsensitive]) == nil
                && name.range(of: macPrefix, options: [.regularExpression, .caseInsensitive]) == nil
        }
    }

    static func mergingVisibleOrder(_ visible: [String], into saved: [String]) -> [String] {
        let visibleSet = Set(visible)
        var iterator = visible.makeIterator()
        return saved.map { visibleSet.contains($0) ? iterator.next() ?? $0 : $0 }
    }
}
