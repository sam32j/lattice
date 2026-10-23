import Foundation

/// Do not enter protected app data just to decide whether it is disposable.
enum CleanerScanPrivacy {
    static func mayInspect(_ name: String) -> Bool {
        if ["musiclibrary", "photoslibrary", "photolibrary"].contains((name as NSString).pathExtension.lowercased()) {
            return false
        }
        guard let owner = CleanerSupport.bundleIDCandidate(fromEntryName: name) else { return true }
        return !CleanerSupport.isProtectedBundleID(owner)
    }
}
