import Foundation

/// Do not enter protected app data just to decide whether it is disposable.
enum CleanerScanPrivacy {
    /// Never offer or remove a whole root if doing so carries excluded data
    /// along with it. Enumeration does not prefetch properties or enter a
    /// protected child; unreadable trees fail closed.
    static func mayRemoveTree(_ root: URL, fm: FileManager) -> Bool {
        guard mayInspect(root.lastPathComponent), !UninstallerSupport.isSymbolicLink(root) else { return false }
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else { return false }
        guard isDirectory.boolValue else { return true }
        var failed = false
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [],
            errorHandler: { _, _ in failed = true; return false }) else { return false }
        for case let item as URL in enumerator {
            guard mayInspect(item.lastPathComponent) else { return false }
            if UninstallerSupport.isSymbolicLink(item) { enumerator.skipDescendants() }
        }
        return !failed
    }

    static func mayInspect(_ name: String) -> Bool {
        if ["musiclibrary", "photoslibrary", "photolibrary"].contains((name as NSString).pathExtension.lowercased()) {
            return false
        }
        guard let owner = CleanerSupport.bundleIDCandidate(fromEntryName: name) else { return true }
        return !CleanerSupport.isProtectedBundleID(owner)
    }
}
