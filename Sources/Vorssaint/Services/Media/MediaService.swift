import AppKit
import Combine

struct MediaResult: Equatable {
    let outputURLs: [URL]
    let originalBytes: Int64
    let outputBytes: Int64
    let unchangedCount: Int
}
enum MediaServiceState: Equatable {
    case idle, running(progress: Double, message: String), completed(MediaResult), failed(String), cancelled
}
final class MediaWorkspaceSelection: ObservableObject {
    @Published var inputURLs: [URL] = []
    @Published var outputURL: URL?
    @Published var tool: MediaTool?
    var loadedInitialInputs = false
}
final class MediaService: ObservableObject {
    static let shared = MediaService()
    @Published private(set) var state: MediaServiceState = .idle
    @Published private(set) var completedOutputs: [URL] = []
    private var generation = UUID()
    private var active: MediaOptimizerClient?
    private let makeClient: () -> MediaOptimizerClient
    private let queue = DispatchQueue(label: "com.lattice.media.optimize", qos: .userInitiated)
    private var quitObserver: NSObjectProtocol?
    init(replacesExistingOutputs: Bool = false, makeClient: @escaping () -> MediaOptimizerClient = { .live }) {
        self.makeClient = makeClient
        quitObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main) { [weak self] _ in self?.cancel(immediately: true) }
    }
    deinit {
        active?.cancel()
        if let quitObserver { NotificationCenter.default.removeObserver(quitObserver) }
    }
    func reset() { cancel(); completedOutputs = []; state = .idle }
    func cancel(immediately: Bool = false) {
        generation = UUID(); active?.cancel(); active = nil; state = .cancelled
    }
    func optimize(inputs: [URL], destination: URL, tool: MediaTool, aggressive: Bool) {
        guard active == nil else { return }
        guard !inputs.isEmpty, inputs.allSatisfy({
            MediaOptimizerPolicy.accepts((try? $0.resourceValues(forKeys: [.contentTypeKey]))?.contentType, tool: tool)
        }) else { state = .failed("Choose images (including GIFs) or videos for the selected category."); return }
        let id = UUID(); generation = id
        let client = makeClient(); active = client
        completedOutputs = []
        state = .running(progress: 0, message: "Preparing files…")
        queue.async { [weak self] in
            guard let self else { return }
            var outputs: [URL] = [], originalBytes: Int64 = 0, outputBytes: Int64 = 0, unchanged = 0
            do {
                for (index, input) in inputs.enumerated() {
                    guard self.isCurrent(id) else { throw CancellationError() }
                    DispatchQueue.main.async {
                        guard self.generation == id else { return }
                        self.state = .running(progress: Double(index) / Double(inputs.count),
                            message: "Optimizing \(index + 1) of \(inputs.count)…")
                    }
                    let staged = try MediaOptimizerPolicy.stage(input, in: destination)
                    defer { try? FileManager.default.removeItem(at: staged.directory) }
                    guard self.isCurrent(id) else { throw CancellationError() }
                    let optimized = try client.optimize(staged.input, aggressive, staged.directory)
                    try MediaOptimizerPolicy.validateOutput(optimized, in: staged.directory)
                    let before = Int64((try staged.input.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)
                    let after = Int64((try optimized.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)
                    let chosen = after < before ? optimized : staged.input
                    if after >= before { unchanged += 1 }
                    var saved: URL?, publicationError: Error?
                    DispatchQueue.main.sync {
                        guard self.generation == id else { return }
                        do {
                            let output = FileOutputSupport.uniqueOutputURL(in: destination,
                                baseName: FileOutputSupport.visibleOutputBaseName(for: input) + "-optimized",
                                fileExtension: chosen.pathExtension)
                            try FileOutputSupport.installStagedOutput(chosen, at: output, replacingExisting: false)
                            saved = output; self.completedOutputs.append(output)
                        } catch { publicationError = error }
                    }
                    if let publicationError { throw publicationError }
                    guard let saved else { throw CancellationError() }
                    outputs.append(saved); originalBytes += before
                    outputBytes += Int64((try saved.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)
                }
                let result = MediaResult(outputURLs: outputs, originalBytes: originalBytes,
                                         outputBytes: outputBytes, unchangedCount: unchanged)
                DispatchQueue.main.async {
                    guard self.generation == id else { return }
                    self.active = nil; self.state = .completed(result)
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.generation == id else { return }
                    self.active = nil
                    let saved = outputs.isEmpty ? "" : " \(outputs.count) completed file(s) remain in the destination."
                    self.state = error is CancellationError ? .cancelled : .failed(error.localizedDescription + saved)
                }
            }
        }
    }
    private func isCurrent(_ id: UUID) -> Bool {
        var current = false
        DispatchQueue.main.sync { current = generation == id }
        return current
    }
}
