import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Scanning the Applications folders

    /// Reads the normal Applications folders plus shallow app results from
    /// Spotlight in the user's home, all off the main thread.
    static func scanInstalledApps(includePublisherFeeds: Bool, cancellation: AppUpdateCheckCancellation? = nil) -> [AppUpdatesSupport.InstalledApp] {
        InstalledApps.applicationScanPaths(
            folderPaths: folderApplicationPaths(cancellation: cancellation),
            spotlightPaths: cancellation?.isCancelled == true ? [] : spotlightApplicationPaths(cancellation: cancellation),
            homeDirectory: NSHomeDirectory()
        ).compactMap { path in
            guard cancellation?.isCancelled != true else { return nil }
            return scannedApp(at: URL(fileURLWithPath: path), includePublisherFeeds: includePublisherFeeds)
        }
    }

    static func folderApplicationPaths(cancellation: AppUpdateCheckCancellation? = nil) -> [String] {
        let fm = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications",
                                                                          isDirectory: true),
        ]
        var paths: [String] = []
        for root in roots where fm.fileExists(atPath: root.path) {
            guard let enumerator = fm.enumerator(at: root,
                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                 options: [.skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator {
                guard cancellation?.isCancelled != true else { return [] }
                guard url.pathExtension == "app" else { continue }
                paths.append(url.path)
            }
        }
        return paths
    }

    static func spotlightApplicationPaths(cancellation: AppUpdateCheckCancellation? = nil) -> [String] {
        let command = HomebrewCommand(
            executable: "/usr/bin/mdfind",
            arguments: ["-onlyin", NSHomeDirectory(),
                        "kMDItemContentType == 'com.apple.application-bundle'"])
        let result = runCommand(command, cancellation: cancellation)
        guard result.status == 0 else { return [] }
        return result.output.split(separator: "\n").map(String.init)
    }

    static func scannedApp(at url: URL, includePublisherFeeds: Bool) -> AppUpdatesSupport.InstalledApp? {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any] else { return nil }
        guard let bundleID = plist["CFBundleIdentifier"] as? String,
              !isOwnBundle(bundleID) else { return nil }
        let version = (plist["CFBundleShortVersionString"] as? String)
            ?? (plist["CFBundleVersion"] as? String) ?? ""
        var name = url.deletingPathExtension().lastPathComponent
        if let display = plist["CFBundleDisplayName"] as? String, !display.isEmpty {
            name = display
        }
        // A store purchase always carries its receipt inside the bundle; it
        // is the only reliable marker macOS gives.
        let hasReceipt = FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path)
        let metadata = hasReceipt ? MDItemCreate(nil, url.path as CFString) : nil
        let storeID = metadata.flatMap {
            MDItemCopyAttribute($0, "kMDItemAppStoreAdamID" as CFString) as? NSNumber
        }.map(\.stringValue)
        var updateFeed: AppUpdateFeedSupport.Feed?
        if includePublisherFeeds, !hasReceipt {
            let configurationURL = url.appendingPathComponent("Contents/Resources/app-update.yml")
            let configurationSize = (try? configurationURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            let configuration = configurationSize.map { $0 <= 64 * 1_024 } == true
                ? (try? String(contentsOf: configurationURL, encoding: .utf8)) : nil
            updateFeed = AppUpdateFeedSupport.feed(info: plist, configuration: configuration)
        }
        // Positron keeps its own release beside its code, not in its bundle.
        let productURL = url.appendingPathComponent("Contents/Resources/app/product.json")
        let productSize = (try? productURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        let productFile = productSize.map { $0 <= 256 * 1_024 } == true ? (try? Data(contentsOf: productURL)) : nil
        let product = AppUpdatesSupport.productRelease(productFile)
        return AppUpdatesSupport.InstalledApp(name: name,
                                              bundleID: bundleID,
                                              path: url.standardizedFileURL.path,
                                              version: product?.version ?? version,
                                              isFromAppStore: hasReceipt,
                                              buildVersion: product?.build ?? plist["CFBundleVersion"] as? String ?? "",
                                              storeID: storeID,
                                              updateFeed: updateFeed)
    }

    /// This app never lists itself: it has its own updater, and letting the
    /// package manager replace a running bundle is exactly what that updater
    /// exists to do safely.
    static func isOwnBundle(_ bundleID: String) -> Bool {
        bundleID == Bundle.main.bundleIdentifier || bundleID == DownstreamIdentity.bundleID
            || bundleID.hasPrefix(DownstreamIdentity.bundleID + ".") || bundleID.hasPrefix("com.vorssaint")
    }

    static let ownPackageTokens: Set<String> = ["lattice", "lattice@beta", "lattice-beta"]

    /// The package manager refreshes its own catalog on the way, which can sit
    /// on a slow network. A ceiling keeps a stalled command from leaving the
    /// check spinning for the rest of the session; the next check simply tries
    /// again.
    static let commandTimeout: TimeInterval = 120
    static let commandOutputLimit = 32 * 1_024 * 1_024

    static func runCommand(_ command: HomebrewCommand,
                                   environment: [String: String]? = nil,
                                   cancellation: AppUpdateCheckCancellation? = nil) -> (status: Int32, output: String) {
        let processCancellation = BoundedProcessCancellation()
        let registration = cancellation?.register { processCancellation.cancel() }
        defer { if let registration { cancellation?.remove(registration) } }
        let result = BoundedProcessRunner.run(command.executable, command.arguments,
                                              timeout: commandTimeout,
                                              maxOutputBytes: commandOutputLimit,
                                              environment: environment, cancellation: processCancellation)
        return (result.status, String(decoding: result.output, as: UTF8.self))
    }}
