import Combine
import Foundation

final class MediaHUDModel: ObservableObject {
    static let shared = MediaHUDModel(allowed: { AppFeature.mediaTools.isAvailable })
    let service: MediaService
    @Published private(set) var inputs: [URL] = []
    @Published private(set) var needsDestination = false
    @Published private(set) var error: String?
    @Published var selectedIndex = 0
    @Published var aggressive = false
    @Published var showsOriginal = false
    @Published private(set) var format: MediaOutputFormat = .original
    private var destination: URL?
    private let writable: (URL) -> Bool
    private let allowed: () -> Bool
    private var intent = UUID()
    private var observation: AnyCancellable?
    init(service: MediaService = MediaService(),
         writable: @escaping (URL) -> Bool = { FileManager.default.isWritableFile(atPath: $0.path) },
         allowed: @escaping () -> Bool = { true }) {
        self.service = service; self.writable = writable; self.allowed = allowed
        observation = service.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    var busy: Bool { if case .running = service.state { return true }; return false }
    var outputs: [URL] { service.completedOutputs }
    var formats: [MediaOutputFormat] { MediaOutputFormat.choices(for: inputs) }
    var selectedOutput: URL? { outputs.indices.contains(selectedIndex) ? outputs[selectedIndex] : nil }
    var selectedOriginal: URL? { inputs.indices.contains(selectedIndex) ? inputs[selectedIndex] : nil }
    @discardableResult
    func receive(_ urls: [URL]) -> Bool {
        guard allowed() else { error = "Media Optimizer is disabled."; return false }
        guard !busy else { error = "An optimization is running. Cancel it before dropping another batch."; return false }
        guard !urls.isEmpty, !MediaOutputFormat.choices(for: urls).isEmpty,
              urls.allSatisfy({ $0.isFileURL && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }) else {
            error = "Drop JPEG, PNG, HEIC, GIF files or videos of the same category. Mixed media, folders and other formats are not supported."
            return false
        }
        inputs = urls; selectedIndex = 0; format = .original
        intent = UUID()
        showsOriginal = false; destination = nil; error = nil
        service.reset()
        run()
        return true
    }
    func chooseDestination(_ url: URL) {
        guard allowed(), !busy else { return }
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            error = "Choose a folder for the optimized copies."; return
        }
        destination = url; needsDestination = false; run()
    }
    func run(format: MediaOutputFormat? = nil) {
        guard allowed(), !busy, !inputs.isEmpty else { return }
        if let format { self.format = format }
        guard self.format == .original || formats.contains(self.format) else {
            error = "That format is not available for these files."; return
        }
        if destination == nil && inputs.contains(where: { !writable($0.deletingLastPathComponent()) }) {
            needsDestination = true; return
        }
        needsDestination = false; error = nil
        let video = formats.contains(.hevc)
        service.optimize(inputs: inputs, destination: destination ?? inputs[0].deletingLastPathComponent(),
                         tool: video ? .videoCompressor : .imageCompressor, aggressive: aggressive,
                         format: self.format, besideOriginals: destination == nil)
    }
    var dialogTicket: UUID { intent }
    func acceptFiles(_ urls: [URL], ticket: UUID) -> Bool {
        guard ticket == intent, allowed() else { return false }
        return receive(urls)
    }
    func acceptDestination(_ url: URL, ticket: UUID) {
        guard ticket == intent, allowed() else { return }
        chooseDestination(url)
    }
    func cancel() { intent = UUID(); service.cancel(); needsDestination = false }
}
