// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Combine
import ImageIO

/// UI state is main-thread owned; each asynchronous job carries a generation.
final class VideoDownloader: ObservableObject {
    static let shared = VideoDownloader()

    @Published var link = ""
    @Published var selectedQuality: VideoDownloadQuality = .best
    @Published var selectedHeight: Int = 0

    @Published private(set) var dependencies: VideoDownloadDependencies
    @Published private(set) var info: VideoDownloadInfo?
    @Published private(set) var destination: URL?
    @Published private(set) var busy = false
    @Published private(set) var isPaused = false
    @Published private(set) var phase = ""
    @Published private(set) var progress: Double?
    @Published private(set) var downloadProgress: DownloadProgress?
    @Published private(set) var error: String?
    @Published private(set) var output: URL?
    @Published private(set) var thumbnailImage: NSImage?

    private var inspectedURL: URL?
    private var job: VideoDownloadProcess?
    private var terminatingJobs: [VideoDownloadProcess] = []
    private var generation = UUID()
    private let queue = DispatchQueue(label: "com.lattice.video-downloader", qos: .userInitiated)
    private let discover: () -> VideoDownloadDependencies
    private var terminationObserver: NSObjectProtocol?

    init(discover: @escaping () -> VideoDownloadDependencies = { .discover() }) {
        self.discover = discover
        self.dependencies = discover()

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
        if !busy {
            info = nil
            inspectedURL = nil
            output = nil
            error = nil
            thumbnailImage = nil
        }
    }

    var isValidURL: Bool {
        (try? VideoDownloadRequest.validatedURL(link)) != nil
    }

    func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        link = text
        linkChanged()
        fetchInfo()
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

    func fetchInfo() {
        guard !busy else { return }
        do {
            let url = try VideoDownloadRequest.validatedURL(link)
            refreshDependencies()
            guard dependencies.ready, let ytdlp = dependencies.tools["yt-dlp"] else {
                throw VideoDownloadError.missingTools
            }
            let tools = dependencies
            info = nil
            inspectedURL = nil
            thumbnailImage = nil
            perform("Fetching video details…") { [weak self] process, id in
                let result = try process.run(
                    executable: ytdlp,
                    arguments: tools.runtimeArguments + VideoDownloadRequest.metadataArguments(url: url),
                    environment: tools.environment,
                    timeout: 90
                )
                let details = try VideoDownloadInfo.decode(result.stdout)
                return { [weak self] in
                    guard let self else { return }
                    self.info = details
                    self.inspectedURL = url
                    self.selectedQuality = details.qualities.first ?? .best
                    self.selectedHeight = self.selectedQuality.height
                    self.phase = ""
                    self.loadThumbnail(details.thumbnailURL, id: id)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadThumbnail(_ url: URL?, id: UUID) {
        guard let url else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 600
            ]
            guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
            let image = NSImage(cgImage: cgThumb, size: NSSize(width: 300, height: 169))
            DispatchQueue.main.async {
                guard self?.generation == id else { return }
                self?.thumbnailImage = image
            }
        }
    }

    func download() {
        let quality = selectedQuality.height != 0
            ? selectedQuality
            : (info?.qualities.first(where: { $0.height == selectedHeight }) ?? selectedQuality)

        guard let url = inspectedURL,
              let destination, dependencies.ready,
              let ytdlp = dependencies.tools["yt-dlp"],
              let ffmpeg = dependencies.tools["ffmpeg"],
              let ffprobe = dependencies.tools["ffprobe"] else { return }

        let tools = dependencies
        let videoTitle = info?.title ?? "video"
        let qualityTag = quality.title

        perform(VideoDownloaderStrings.downloading) { [weak self] process, id in
            let manager = FileManager.default
            let staging = destination.appendingPathComponent(".lattice-download-\(UUID().uuidString)", isDirectory: true)
            try manager.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? manager.removeItem(at: staging) }

            let result = try process.run(
                executable: ytdlp,
                arguments: tools.runtimeArguments + VideoDownloadRequest.downloadArguments(
                    url: url,
                    quality: quality,
                    staging: staging,
                    ffmpeg: ffmpeg
                ),
                environment: tools.environment,
                timeout: 6 * 3600,
                stdoutLimit: 4_000_000
            ) { line in
                if let parsed = VideoDownloadRequest.parseProgress(line) {
                    DispatchQueue.main.async {
                        guard self?.generation == id else { return }
                        self?.progress = parsed.fraction
                        self?.downloadProgress = parsed
                        self?.phase = parsed.fraction >= 1 ? VideoDownloaderStrings.finishingVideo : VideoDownloaderStrings.downloading
                    }
                } else if let fraction = VideoDownloadRequest.progress(line) {
                    DispatchQueue.main.async {
                        guard self?.generation == id else { return }
                        self?.progress = fraction
                        self?.phase = fraction >= 1 ? VideoDownloaderStrings.finishingVideo : VideoDownloaderStrings.downloading
                    }
                }
            }

            guard let path = String(decoding: result.stdout, as: UTF8.self).split(separator: "\n")
                .last(where: { $0.hasPrefix("LATTICE_FILE:") })
                .map({ String($0.dropFirst("LATTICE_FILE:".count)) }) else {
                throw VideoDownloadError.invalidOutput
            }

            let file = try VideoDownloadRequest.validatedOutput(URL(fileURLWithPath: path), from: staging)
            let probe = try process.run(
                executable: ffprobe,
                arguments: ["-v", "error", "-select_streams", quality.isAudio ? "a:0" : "v:0",
                            "-show_entries", "stream=codec_type,width,height:format=duration",
                            "-of", "json", "-i", file.path],
                environment: tools.environment,
                timeout: 30,
                stdoutLimit: 256_000
            )

            guard VideoDownloadRequest.hasPlayableMedia(probe.stdout, isAudio: quality.isAudio) else {
                throw VideoDownloadError.invalidOutput
            }

            var saved: URL?
            var publishError: Error?
            DispatchQueue.main.sync {
                guard self?.generation == id else { return }
                do {
                    saved = try VideoDownloadRequest.publish(file, from: staging, to: destination)
                    self?.output = saved
                } catch {
                    publishError = error
                }
            }
            if let publishError { throw publishError }
            guard let saved else { throw CancellationError() }

            return { [weak self] in
                self?.output = saved
                self?.phase = VideoDownloaderStrings.downloadComplete
                self?.progress = nil
                self?.downloadProgress = nil
                DownloadHistoryStore.shared.record(fileURL: saved, title: videoTitle, qualityTag: qualityTag)
            }
        }
    }

    private func perform(_ title: String,
                         work: @escaping (VideoDownloadProcess, UUID) throws -> () -> Void) {
        guard !busy else { return }
        let process = VideoDownloadProcess()
        let id = UUID()
        generation = id
        job = process
        busy = true
        isPaused = false
        error = nil
        output = nil
        progress = nil
        downloadProgress = nil
        phase = title

        queue.async { [weak self] in
            do {
                let finish = try work(process, id)
                DispatchQueue.main.async {
                    self?.terminatingJobs.removeAll { $0 === process }
                    guard self?.generation == id else { return }
                    self?.busy = false
                    self?.isPaused = false
                    self?.job = nil
                    finish()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.terminatingJobs.removeAll { $0 === process }
                    guard self?.generation == id else { return }
                    self?.busy = false
                    self?.isPaused = false
                    self?.job = nil
                    self?.progress = nil
                    self?.downloadProgress = nil
                    self?.phase = ""
                    self?.error = error is CancellationError ? "Cancelled." : error.localizedDescription
                    if let self { self.dependencies = self.discover() }
                }
            }
        }
    }
}
