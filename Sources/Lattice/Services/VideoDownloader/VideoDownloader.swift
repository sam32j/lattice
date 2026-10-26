// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Combine
import ImageIO

/// UI state is main-thread owned; each asynchronous job carries a generation.
final class VideoDownloader: ObservableObject {
    static let shared = VideoDownloader()

    @Published var link = "" {
        didSet { if link != oldValue { linkChanged() } }
    }
    @Published var selectedQuality: VideoDownloadQuality = .best
    @Published var selectedHeight: Int = 0

    @Published var dependencies: VideoDownloadDependencies
    @Published var info: VideoDownloadInfo?
    @Published var destination: URL?
    @Published var busy = false
    @Published var isFetching = false
    @Published var isDownloading = false
    @Published var isPaused = false
    @Published var phase = ""
    @Published var progress: Double?
    @Published var downloadProgress: DownloadProgress?
    @Published var error: String?
    @Published var output: URL?
    @Published var thumbnailImage: NSImage?
    @Published var isCompletedSustaining = false

    var completionSustainTimer: DispatchWorkItem?
    var inspectedURL: URL?
    private var lastHandledLink = ""
    var job: VideoDownloadProcess?
    var terminatingJobs: [VideoDownloadProcess] = []
    var generation = UUID()
    let queue = DispatchQueue(label: "com.lattice.video-downloader", qos: .userInitiated)
    let discover: () -> VideoDownloadDependencies
    let historyStore: DownloadHistoryStore
    let completionFeedback: () -> Void
    let readClipboard: () -> String?
    var terminationObserver: NSObjectProtocol?

    init(discover: @escaping () -> VideoDownloadDependencies = { .discover() },
         historyStore: DownloadHistoryStore = .shared,
         completionFeedback: @escaping () -> Void = VideoDownloader.playCompletionSound,
         readClipboard: @escaping () -> String? = { NSPasteboard.general.string(forType: .string) }) {
        self.discover = discover
        self.dependencies = discover()
        self.historyStore = historyStore
        self.completionFeedback = completionFeedback
        self.readClipboard = readClipboard

        // Load saved destination or default to ~/Downloads
        if let savedPath = UserDefaults.standard.string(forKey: DefaultsKey.videoDownloaderDestination) {
            let url = URL(fileURLWithPath: (savedPath as NSString).expandingTildeInPath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                self.destination = url
            }
        }
        if self.destination == nil {
            self.destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.job?.cancel(immediately: true)
            self?.terminatingJobs.forEach { $0.cancel(immediately: true) }
        }
    }

    deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        job?.cancel(immediately: true)
        terminatingJobs.forEach { $0.cancel(immediately: true) }
    }

    func refreshDependencies() {
        guard !busy else { return }
        dependencies = discover()
        ToolchainManager.shared.checkHealth()
    }

    func linkChanged() {
        guard link != lastHandledLink else { return }
        lastHandledLink = link
        if isFetching { cancel() }
        inspectedURL = nil
        guard !busy else { return } // An edited draft must not cancel an active download.
        generation = UUID() // Invalidate any thumbnail request from the old inspected link.
        cancelCompletionSustain()
        info = nil
        output = nil
        error = nil
        thumbnailImage = nil
        progress = nil
        downloadProgress = nil
        phase = ""
        isFetching = false
        isDownloading = false
    }

    var hasCurrentSearchResult: Bool { inspectedURL != nil && (info != nil || output != nil) }

    var isValidURL: Bool {
        (try? VideoDownloadRequest.validatedURL(link)) != nil
    }

    func pasteFromClipboard() {
        guard let text = readClipboard()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        link = text
        linkChanged()
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose folder"
        panel.directoryURL = destination ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.selectDestination(url)
            }
        }
    }

    func selectDestination(_ url: URL) {
        guard !busy, url.isFileURL,
              (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return }
        destination = url
        UserDefaults.standard.set(url.path, forKey: DefaultsKey.videoDownloaderDestination)
    }

    func pause() {
        guard busy, !isPaused, let job else { return }
        job.pause()
        isPaused = true
        phase = VideoDownloaderStrings.paused
    }

    func resume() {
        guard busy, isPaused, let job else { return }
        job.resume()
        isPaused = false
        phase = VideoDownloaderStrings.downloading
    }

    func cancel() {
        generation = UUID()
        if let job {
            terminatingJobs.append(job)
            job.cancel()
        }
        job = nil
        busy = false
        isFetching = false
        isDownloading = false
        isPaused = false
        progress = nil
        downloadProgress = nil
        phase = output == nil ? "Cancelled. Partial files will be removed." : "Download complete."
    }

    func teardown() {
        cancel()
        link = ""
        info = nil
        inspectedURL = nil
        thumbnailImage = nil
        output = nil
        error = nil
        phase = ""
    }

    func installTools() {
        ToolchainManager.shared.repair()
    }

    var isExpandedFocused: () -> Bool = { false }

    func startCompletionSustain() {
        completionSustainTimer?.cancel()
        isCompletedSustaining = true
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isCompletedSustaining = false
            if !self.isExpandedFocused() {
                self.resetDownloadState()
            }
            self.objectWillChange.send()
        }
        completionSustainTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: item)
    }

    func cancelCompletionSustain() {
        completionSustainTimer?.cancel()
        completionSustainTimer = nil
        if isCompletedSustaining {
            isCompletedSustaining = false
        }
    }

    func resetDownloadState() {
        let shouldClearLink = hasCurrentSearchResult
        cancelCompletionSustain()
        output = nil
        info = nil
        inspectedURL = nil
        if shouldClearLink { link = "" }
        progress = nil
        downloadProgress = nil
        thumbnailImage = nil
        phase = ""
        error = nil
        isDownloading = false
        isPaused = false
    }

}
