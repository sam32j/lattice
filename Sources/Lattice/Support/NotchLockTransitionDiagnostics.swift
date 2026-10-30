#if LATTICE_DEVELOPMENT
import AppKit
import os

/// Records only this process's window IDs and geometry. The window-list query
/// is filtered before logging; no screen contents, titles or other applications'
/// metadata are logged or retained.
enum NotchLockTransitionDiagnostics {
    private static let logger = Logger(subsystem: "io.github.sam32j.lattice", category: "LockTransition")
    private static let queue = DispatchQueue(label: "io.github.sam32j.lattice.lock-diagnostics", qos: .utility)

    static func begin(outgoingWindow: Int) {
        let token = UUID().uuidString
        let revision = Bundle.main.object(forInfoDictionaryKey: "LatticeBuildCommit") as? String ?? "unavailable"
        logger.info("Begin lock \(token, privacy: .public), source=\(outgoingWindow, privacy: .public), build=\(revision, privacy: .public)")
        for index in 0..<30 {
            queue.asyncAfter(deadline: .now() + Double(index) / 30) {
                sample(token: token, index: index, outgoingWindow: outgoingWindow)
            }
        }
    }

    static func event(_ phase: String, window: Int) {
        logger.info("\(phase, privacy: .public) window=\(window, privacy: .public)")
    }

    private static func sample(token: String, index: Int, outgoingWindow: Int) {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else {
            logger.error("Window list unavailable for \(token, privacy: .public)"); return
        }
        let own = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == getpid() }
        let descriptions = own.map { item -> String in
            let number = item[kCGWindowNumber as String] as? Int ?? -1
            let layer = item[kCGWindowLayer as String] as? Int ?? 0
            let alpha = item[kCGWindowAlpha as String] as? Double ?? 0
            let bounds = (item[kCGWindowBounds as String] as? [String: Any])
                .flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) }
            return "id=\(number) layer=\(layer) alpha=\(alpha) bounds=\(bounds.map(String.init(describing:)) ?? "unavailable")"
        }.joined(separator: "; ")
        let sourcePresent = own.contains { ($0[kCGWindowNumber as String] as? Int) == outgoingWindow }
        logger.info("Sample \(token, privacy: .public) #\(index, privacy: .public) sourcePresent=\(sourcePresent, privacy: .public): \(descriptions, privacy: .public)")
    }
}
#endif
