import Foundation
import UniformTypeIdentifiers

enum MediaTool: String, CaseIterable, Identifiable {
    case imageCompressor, videoCompressor
    var id: String { rawValue }
    var title: String { self == .imageCompressor ? "Images" : "Videos" }
}

enum MediaOptimizerPolicy {
    struct Staged { let directory: URL; let input: URL }
    static func accepts(_ type: UTType?, tool: MediaTool) -> Bool {
        guard let type else { return false }
        return tool == .imageCompressor ? type.conforms(to: .image) : type.conforms(to: .movie) || type.conforms(to: .video)
    }
    static func stage(_ original: URL, in destination: URL) throws -> Staged {
        let fm = FileManager.default
        guard original.isFileURL, destination.isFileURL,
              try original.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let directory = destination.appendingPathComponent(".lattice-optimize-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        let input = directory.appendingPathComponent(original.lastPathComponent)
        do { try fm.copyItem(at: original, to: input) }
        catch { try? fm.removeItem(at: directory); throw error }
        return Staged(directory: directory, input: input)
    }
    static func validateOutput(_ output: URL, in directory: URL) throws {
        guard try output.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let file = output.resolvingSymlinksInPath().standardizedFileURL
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard file.path.hasPrefix(root.path + "/"), values.isRegularFile == true, (values.fileSize ?? 0) > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
}
