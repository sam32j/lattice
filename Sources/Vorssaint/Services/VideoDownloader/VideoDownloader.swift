import AppKit
import Combine

/// UI state is main-thread owned; each asynchronous job carries a generation.
final class VideoDownloader: ObservableObject {
    static let shared = VideoDownloader()
    @Published var link = ""
    @Published var selectedHeight = 0
    @Published private(set) var dependencies = VideoDownloadDependencies.discover()
    @Published private(set) var info: VideoDownloadInfo?
    @Published private(set) var destination: URL?
    @Published private(set) var busy = false
    @Published private(set) var phase = ""
    @Published private(set) var progress: Double?
    @Published private(set) var error: String?
    @Published private(set) var output: URL?
    private var inspectedURL: URL?
    private var job: VideoDownloadProcess?
    private var terminatingJobs: [VideoDownloadProcess] = []
    private var generation = UUID()
    private let queue = DispatchQueue(label: "com.lattice.video-downloader", qos: .userInitiated)
    private let discover: () -> VideoDownloadDependencies
    private var terminationObserver: NSObjectProtocol?

    init(discover: @escaping () -> VideoDownloadDependencies = { .discover() }) {
        self.discover = discover; dependencies = discover()
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.job?.cancel(immediately: true)
                self?.terminatingJobs.forEach { $0.cancel(immediately: true) }
            }
    }
    deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        job?.cancel(immediately: true)
        terminatingJobs.forEach { $0.cancel(immediately: true) }
    }

    func refreshDependencies() { guard !busy else { return }; dependencies = discover() }
    func linkChanged() { if !busy { info = nil; inspectedURL = nil; output = nil; error = nil } }

    func cancel() {
        generation = UUID()
        if let job { terminatingJobs.append(job); job.cancel() }
        job = nil
        busy = false; progress = nil
        phase = output == nil ? "Cancelled. Partial files will be removed." : "Download complete."
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = "Choose folder"
        panel.directoryURL = destination ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url { self?.selectDestination(url) }
        }
    }

    func selectDestination(_ url: URL) {
        guard !busy, url.isFileURL,
              (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return }
        destination = url
    }

    func installTools() {
        refreshDependencies()
        guard !busy, let brew = dependencies.brew, !dependencies.ready else { return }
        let tools = dependencies
        perform("Installing tools with Homebrew…") { [weak self] process, _ in
            _ = try process.run(executable: brew, arguments: tools.installArguments,
                environment: tools.environment, timeout: 1800, stdoutLimit: 2_000_000)
            guard let self else { throw CancellationError() }
            let discovered = self.discover()
            guard discovered.ready else { throw VideoDownloadError.missingTools }
            return { [weak self] in self?.dependencies = discovered; self?.phase = "Tools are ready." }
        }
    }

    func fetchInfo() {
        guard !busy else { return }
        do {
            let url = try VideoDownloadRequest.validatedURL(link)
            refreshDependencies()
            guard dependencies.ready, let ytdlp = dependencies.tools["yt-dlp"] else { throw VideoDownloadError.missingTools }
            let tools = dependencies
            info = nil; inspectedURL = nil
            perform("Fetching video details…") { [weak self] process, _ in
                let result = try process.run(executable: ytdlp,
                    arguments: tools.runtimeArguments + VideoDownloadRequest.metadataArguments(url: url),
                    environment: tools.environment, timeout: 90)
                let details = try VideoDownloadInfo.decode(result.stdout)
                return { [weak self] in
                    self?.info = details; self?.inspectedURL = url
                    self?.selectedHeight = details.qualities.first?.height ?? 0; self?.phase = ""
                }
            }
        } catch { self.error = error.localizedDescription }
    }

    func download() {
        guard let url = inspectedURL, let quality = info?.qualities.first(where: { $0.height == selectedHeight }),
              let destination, dependencies.ready,
              let ytdlp = dependencies.tools["yt-dlp"], let ffmpeg = dependencies.tools["ffmpeg"],
              let ffprobe = dependencies.tools["ffprobe"] else { return }
        let tools = dependencies
        perform("Downloading video…") { [weak self] process, id in
            let manager = FileManager.default
            // A hidden child on the chosen volume gives the final move/copy a
            // predictable boundary, and cancellation never deletes user files.
            let staging = destination.appendingPathComponent(".lattice-download-\(UUID().uuidString)", isDirectory: true)
            try manager.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? manager.removeItem(at: staging) }
            let result = try process.run(executable: ytdlp,
                arguments: tools.runtimeArguments + VideoDownloadRequest.downloadArguments(url: url, quality: quality,
                    staging: staging, ffmpeg: ffmpeg), environment: tools.environment,
                timeout: 6 * 3600, stdoutLimit: 4_000_000) { line in
                    guard let fraction = VideoDownloadRequest.progress(line) else { return }
                    DispatchQueue.main.async {
                        guard self?.generation == id else { return }
                        self?.progress = fraction
                        self?.phase = fraction >= 1 ? "Finishing video…" : "Downloading video…"
                    }
                }
            guard let path = String(decoding: result.stdout, as: UTF8.self).split(separator: "\n")
                .last(where: { $0.hasPrefix("LATTICE_FILE:") }).map({ String($0.dropFirst("LATTICE_FILE:".count)) }) else {
                throw VideoDownloadError.invalidOutput
            }
            let video = try VideoDownloadRequest.validatedOutput(URL(fileURLWithPath: path), from: staging)
            let probe = try process.run(executable: ffprobe,
                arguments: ["-v", "error", "-select_streams", "v:0", "-show_entries",
                    "stream=codec_type,width,height:format=duration", "-of", "json", "-i", video.path],
                environment: tools.environment, timeout: 30, stdoutLimit: 256_000)
            guard VideoDownloadRequest.hasPlayableVideo(probe.stdout) else { throw VideoDownloadError.invalidOutput }
            // Cancel and publication serialize through the main actor. A cancelled
            // worker never copies a late completed file into the destination.
            var saved: URL?
            var publishError: Error?
            DispatchQueue.main.sync {
                guard self?.generation == id else { return }
                do {
                    saved = try VideoDownloadRequest.publish(video, from: staging, to: destination)
                    self?.output = saved
                }
                catch { publishError = error }
            }
            if let publishError { throw publishError }
            guard let saved else { throw CancellationError() }
            return { [weak self] in self?.output = saved; self?.phase = "Download complete."; self?.progress = nil }
        }
    }

    private func perform(_ title: String,
                         work: @escaping (VideoDownloadProcess, UUID) throws -> () -> Void) {
        guard !busy else { return }
        let process = VideoDownloadProcess(), id = UUID()
        generation = id; job = process; busy = true; error = nil; output = nil; progress = nil; phase = title
        queue.async { [weak self] in
            do {
                let finish = try work(process, id)
                DispatchQueue.main.async {
                    self?.terminatingJobs.removeAll { $0 === process }
                    guard self?.generation == id else { return }
                    self?.busy = false; self?.job = nil; finish()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.terminatingJobs.removeAll { $0 === process }
                    guard self?.generation == id else { return }
                    self?.busy = false; self?.job = nil; self?.progress = nil; self?.phase = ""
                    self?.error = error is CancellationError ? "Cancelled." : error.localizedDescription
                    if let self { self.dependencies = self.discover() }
                }
            }
        }
    }
}
