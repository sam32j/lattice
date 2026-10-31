// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import CoreServices
import Darwin
import Security

/// Finds the files an app leaves around — caches, preferences, logs, support
/// folders, containers, preference panes, plugins — and removes only what you
/// pick. Ordinary files go to the Trash; after an extra confirmation, a
/// package-managed app is delegated to its package manager before the remaining
/// choices go to the Trash.
extension AppUninstaller {

    // MARK: - Scanning

    static func collect(appURL: URL,
                                primaryBundleID: String,
                                exclusiveBundleIDs: Set<String>,
                                teamIDs: Set<String>,
                                exclusiveGroupIDs: Set<String>,
                                cancellation: UninstallerSupport.ScanCancellation) -> [Leftover] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var paths = [ScanCandidate(url: appURL, category: .app,
                                   ownerBundleID: nil, ownerGroupID: nil,
                                   evidenceBundleID: nil,
                                   confidence: .exact, include: true)]
        let bundle = Bundle(url: appURL)
        var displayNames = UninstallerSupport.displayNames(
            localizedName: fm.displayName(atPath: appURL.path),
            fileName: appURL.lastPathComponent,
            bundleName: bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
            bundleDisplayName: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        )
        if let executable = bundle?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String {
            displayNames.append(executable)
        }
        let identity = UninstallerSupport.identity(
            primaryBundleID: primaryBundleID,
            bundleIDs: exclusiveBundleIDs,
            displayNames: displayNames,
            teamIDs: teamIDs,
            groupIDs: exclusiveGroupIDs
        )
        let allowedRoots = scanRoots(home: home)

        for folder in UninstallerSupport.searchFolders(
            home: URL(fileURLWithPath: home, isDirectory: true),
            darwinCache: darwinUserDirectory(_CS_DARWIN_USER_CACHE_DIR),
            darwinTemp: darwinUserDirectory(_CS_DARWIN_USER_TEMP_DIR)
        ) {
            guard !cancellation.isCancelled else { return [] }
            appendMatches(in: folder, identity: identity, fm: fm, into: &paths)
        }
        guard !cancellation.isCancelled else { return [] }
        appendSpotlightMatches(identity: identity, roots: spotlightRoots(home: home),
                               fm: fm, into: &paths)

        // Last line of defense: nothing outside the scanned roots (or the app
        // bundle itself) may ever reach the removal list.
        let appPath = appURL.standardizedFileURL.path
        let safe = dedupe(paths).filter { candidate in
            let path = candidate.url.standardizedFileURL.path
            if path == appPath {
                return !UninstallerSupport.isSymbolicLink(candidate.url)
            }
            guard let root = allowedRoots.first(where: { path.hasPrefix($0.path + "/") }) else {
                return false
            }
            return UninstallerSupport.removalPathIsSafe(candidate.url, within: root)
        }
        return safe
            .compactMap { candidate -> Leftover? in
                // Sizing walks every folder found; stop there too.
                guard !cancellation.isCancelled,
                      let fileIdentity = UninstallerSupport.fileIdentity(at: candidate.url) else {
                    return nil
                }
                return Leftover(url: candidate.url, category: candidate.category,
                                size: directorySize(of: candidate.url, fm: fm),
                                ownerBundleID: candidate.ownerBundleID,
                                ownerGroupID: candidate.ownerGroupID,
                                evidenceBundleID: candidate.evidenceBundleID,
                                confidence: candidate.confidence,
                                fileIdentity: fileIdentity,
                                include: candidate.include)
            }
            .sorted { ($0.category.sortRank, -$0.size) < ($1.category.sortRank, -$1.size) }
    }

    static func appendMatches(in folder: UninstallerSupport.SearchFolder,
                                      identity: UninstallerSupport.Identity,
                                      fm: FileManager,
                                      into paths: inout [ScanCandidate]) {
        let listings = dirListings(at: folder.url, remainingDepth: folder.extraChildDepth, fm: fm)
        guard !listings.isEmpty else { return }
        let category = category(for: folder.kind)
        let matchingIdentity: UninstallerSupport.Identity
        if folder.requiresSignedGroup {
            matchingIdentity = UninstallerSupport.Identity(
                bundleIDs: [], nameTokens: [], teamIDs: [], groupIDs: identity.groupIDs)
        } else {
            matchingIdentity = folder.allowsNameMatches
                ? identity : UninstallerSupport.technicalIdentity(identity)
        }
        var claimed = Set<String>()
        for hit in UninstallerSupport.leftoverHitRecords(
            listings: listings,
            identity: matchingIdentity,
            extraChildDepth: folder.extraChildDepth,
            crashReporter: folder.crashReporter
        ) {
            claimed.insert(hit.path)
            appendHit(hit, folder: folder.url, category: category, identity: matchingIdentity,
                      crashReporter: folder.crashReporter, into: &paths)
        }
        guard folder.readsContainerMetadata else { return }
        for listing in listings where !claimed.contains(listing.name) {
            let url = folder.url.appendingPathComponent(listing.name)
            guard let identifier = containerMetadataIdentifier(at: url) else { continue }
            let match = UninstallerSupport.containerMetadataMatches(identifier, identity: matchingIdentity)
            guard match != .none else { continue }
            claimed.insert(listing.name)
            let groupID = UninstallerSupport.matchingGroupID(identifier, identity: matchingIdentity)
                ?? UninstallerSupport.matchingGroupID(listing.name, identity: matchingIdentity)
            let owner = groupID == nil
                ? (UninstallerSupport.ownerBundleID(for: identifier, identity: matchingIdentity)
                    ?? UninstallerSupport.ownerBundleID(for: listing.name, identity: matchingIdentity)
                    ?? matchingIdentity.bundleIDs.min(by: { $0.count < $1.count }))
                : nil
            guard owner != nil || groupID != nil else { continue }
            let evidence = groupID == nil
                ? UninstallerSupport.verifiedBundleID(identifier) : nil
            paths.append(ScanCandidate(url: url, category: category,
                                       ownerBundleID: owner, ownerGroupID: groupID,
                                       evidenceBundleID: evidence,
                                       confidence: match, include: match == .exact))
        }
    }

    static func appendHit(_ hit: UninstallerSupport.Hit,
                                  folder: URL,
                                  category: Category,
                                  identity: UninstallerSupport.Identity,
                                  crashReporter: Bool,
                                  into paths: inout [ScanCandidate]) {
        let relative = hit.path
        let name = (relative as NSString).lastPathComponent
        let identifier = hit.bundleIdentifier
            ?? CleanerSupport.bundleIDCandidate(fromEntryName: name)
        let groupID = identifier.flatMap {
            UninstallerSupport.matchingGroupID($0, identity: identity)
        } ?? UninstallerSupport.matchingGroupID(name, identity: identity)
        let owner = groupID == nil
            ? (identifier.flatMap { UninstallerSupport.ownerBundleID(for: $0, identity: identity) }
                ?? UninstallerSupport.ownerBundleID(for: name, identity: identity,
                                                crashReporter: crashReporter)
                ?? identity.bundleIDs.min(by: { $0.count < $1.count }))
            : nil
        guard owner != nil || groupID != nil else { return }
        let url = relative.split(separator: "/").reduce(folder) {
            $0.appendingPathComponent(String($1))
        }
        paths.append(ScanCandidate(url: url, category: category,
                                   ownerBundleID: owner, ownerGroupID: groupID,
                                   evidenceBundleID: groupID == nil ? identifier : nil,
                                   confidence: hit.confidence,
                                   include: hit.confidence == .exact))
    }

    static func dirListings(at url: URL,
                                    remainingDepth: Int,
                                    fm: FileManager) -> [UninstallerSupport.DirListing] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let entries = try? fm.contentsOfDirectory(at: url,
                                                        includingPropertiesForKeys: Array(keys),
                                                        options: []) else { return [] }
        return entries.compactMap { entry -> UninstallerSupport.DirListing? in
            let name = entry.lastPathComponent
            guard !name.hasPrefix(".") else { return nil }
            let values = try? entry.resourceValues(forKeys: keys)
            guard values?.isSymbolicLink != true else { return nil }
            var children: [UninstallerSupport.DirListing] = []
            if remainingDepth > 0, values?.isDirectory == true {
                children = dirListings(at: entry, remainingDepth: remainingDepth - 1, fm: fm)
            }
            let bundleIdentifier = packageExtensions.contains(entry.pathExtension.lowercased())
                ? UninstallerSupport.verifiedBundleID(Bundle(url: entry)?.bundleIdentifier)
                : nil
            return UninstallerSupport.DirListing(name: name, children: children,
                                                  bundleIdentifier: bundleIdentifier)
        }
    }

    static func containerMetadataIdentifier(at url: URL) -> String? {
        let metadata = url.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        guard let dict = NSDictionary(contentsOf: metadata) as? [String: Any] else { return nil }
        return dict["MCMMetadataIdentifier"] as? String
    }

    static func appendSpotlightMatches(identity: UninstallerSupport.Identity,
                                               roots: [URL],
                                               fm: FileManager,
                                               into paths: inout [ScanCandidate]) {
        guard let expression = UninstallerSupport.leftoverSpotlightExpression(identity: identity)
        else { return }
        let scopes = roots.map(\.path).filter { fm.fileExists(atPath: $0) }
        guard !scopes.isEmpty,
              let query = MDQueryCreate(kCFAllocatorDefault, expression as CFString, nil, nil)
        else { return }
        MDQuerySetMaxCount(query, 200)
        MDQuerySetSearchScope(query, scopes as CFArray, 0)
        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else { return }
        let count = min(MDQueryGetResultCount(query), 200)
        var added = 0
        for index in 0..<count {
            guard added < 80,
                  let raw = MDQueryGetResultAtIndex(query, index) else { continue }
            let item = unsafeBitCast(raw, to: MDItem.self)
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String,
                  UninstallerSupport.leftoverSpotlightPathIsAllowed(path, roots: roots)
            else { continue }
            let url = URL(fileURLWithPath: path)
            let matchingIdentity = UninstallerSupport.spotlightIdentity(for: path, identity: identity)
            let match = UninstallerSupport.leftoverMatch(
                url.lastPathComponent, identity: matchingIdentity)
            guard match != .none else { continue }
            let groupID = UninstallerSupport.matchingGroupID(
                url.lastPathComponent, identity: matchingIdentity)
            let evidence = groupID == nil
                ? CleanerSupport.bundleIDCandidate(fromEntryName: url.lastPathComponent) : nil
            let owner = groupID == nil
                ? (UninstallerSupport.ownerBundleID(
                    for: evidence ?? url.lastPathComponent, identity: matchingIdentity)
                    ?? matchingIdentity.bundleIDs.min(by: { $0.count < $1.count }))
                : nil
            guard owner != nil || groupID != nil else { continue }
            paths.append(ScanCandidate(url: url, category: category(forPath: path),
                                       ownerBundleID: owner, ownerGroupID: groupID,
                                       evidenceBundleID: evidence,
                                       confidence: match, include: false))
            added += 1
        }
    }

    static func category(forPath path: String) -> Category {
        if path.contains("/Caches") { return .caches }
        if path.contains("/Preferences") { return .preferences }
        if path.contains("/Group Containers") || path.contains("/Containers") { return .containers }
        if path.contains("/Logs") { return .logs }
        if path.contains("/Saved Application State") { return .state }
        if path.contains("/Application Support") { return .support }
        return .other
    }

    static func codeSigningIdentity(at appURL: URL,
                                            requireValidSignature: Bool)
        -> (teamIDs: Set<String>, groupIDs: Set<String>) {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return ([], []) }
        if requireValidSignature,
           SecStaticCodeCheckValidity(staticCode, [], nil) != errSecSuccess {
            return ([], [])
        }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let info else { return ([], []) }
        let dict = info as NSDictionary
        var teamIDs: Set<String> = []
        if let team = dict[kSecCodeInfoTeamIdentifier] as? String {
            teamIDs.insert(team)
        }
        var groupIDs: Set<String> = []
        if let entitlements = dict[kSecCodeInfoEntitlementsDict] as? [String: Any],
           let groups = entitlements["com.apple.security.application-groups"] as? [String] {
            groupIDs.formUnion(groups.filter { !$0.isEmpty })
        }
        return (teamIDs, groupIDs)
    }
}
