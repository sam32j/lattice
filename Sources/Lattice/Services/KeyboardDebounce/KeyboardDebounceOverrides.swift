import Foundation

/// The existing comma-separated preference is also the user-visible insertion order.
enum KeyboardDebounceOverrides {
    struct Entry: Equatable {
        let keyCode: Int64
        var window: Int
    }

    static func decode(_ raw: String) -> [Entry] {
        var entries: [Entry] = []
        for part in raw.split(separator: ",") {
            let pair = part.split(separator: ":", maxSplits: 1)
            guard pair.count == 2, let code = Int64(pair[0]), let value = Int(pair[1]) else { continue }
            let window = Defaults.sanitizedKeyboardDebounceWindow(value)
            if let index = entries.firstIndex(where: { $0.keyCode == code }) { entries[index].window = window }
            else { entries.append(Entry(keyCode: code, window: window)) }
        }
        return entries
    }

    static func setting(_ value: Int, for keyCode: Int64, in raw: String) -> String {
        var entries = decode(raw)
        let value = Defaults.sanitizedKeyboardDebounceWindow(value)
        if let index = entries.firstIndex(where: { $0.keyCode == keyCode }) { entries[index].window = value }
        else { entries.append(Entry(keyCode: keyCode, window: value)) }
        return encode(entries)
    }

    static func removing(_ keyCode: Int64, from raw: String) -> String {
        encode(decode(raw).filter { $0.keyCode != keyCode })
    }

    private static func encode(_ entries: [Entry]) -> String {
        entries.map { "\($0.keyCode):\($0.window)" }.joined(separator: ",")
    }
}
