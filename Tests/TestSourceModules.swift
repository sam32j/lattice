import Foundation

/// Source audit fixtures follow a module across cohesive extension files.
enum TestSourceModules {
    static func read(_ path: String) -> String {
        let base = URL(fileURLWithPath: path)
        let files = (try? FileManager.default.contentsOfDirectory(at: base.deletingLastPathComponent(),
            includingPropertiesForKeys: nil)) ?? []
        return ([base] + files.filter {
            $0.lastPathComponent.hasPrefix(base.deletingPathExtension().lastPathComponent + "+")
                && $0.pathExtension == "swift"
        }.sorted { $0.path < $1.path }).compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }
}
