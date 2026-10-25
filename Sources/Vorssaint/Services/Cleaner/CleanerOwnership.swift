import Foundation

enum CleanerOwnership {
    static func owner(at url: URL, usesContainerMetadata: Bool,
                      readMetadata: (URL) -> String? = metadataOwner) -> String? {
        let name = url.lastPathComponent
        guard !name.lowercased().hasSuffix(".localized"), CleanerScanPrivacy.mayInspect(name) else { return nil }
        if usesContainerMetadata, let owner = readMetadata(url),
           !CleanerSupport.hasSharedContainerWrapper(owner),
           let candidate = CleanerSupport.bundleIDCandidate(fromEntryName: owner) {
            return candidate
        }
        guard !CleanerSupport.hasSharedContainerWrapper(name) else { return nil }
        return CleanerSupport.bundleIDCandidate(fromEntryName: name)
    }

    private static func metadataOwner(_ url: URL) -> String? {
        let metadata = url.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        return NSDictionary(contentsOf: metadata)?["MCMMetadataIdentifier"] as? String
    }
}
