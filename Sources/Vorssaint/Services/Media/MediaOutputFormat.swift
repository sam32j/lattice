import Foundation
import UniformTypeIdentifiers

enum MediaOutputFormat: String, CaseIterable, Identifiable {
    case original, jpeg, png, heic, gif, h264, hevc
    var id: Self { self }
    var title: String {
        switch self {
        case .original: return "Optimize"
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .gif: return "GIF"
        case .h264: return "H.264"
        case .hevc: return "HEVC"
        }
    }
    static func choices(for urls: [URL]) -> [Self] {
        let types = urls.compactMap { (try? $0.resourceValues(forKeys: [.contentTypeKey]))?.contentType }
        guard !types.isEmpty, types.count == urls.count else { return [] }
        if types.allSatisfy({ $0.conforms(to: .movie) || $0.conforms(to: .video) }) { return [.h264, .hevc] }
        if types.allSatisfy({ $0 == .gif }) { return [.gif] }
        if types.allSatisfy({ $0 == .jpeg || $0 == .png || $0.conforms(to: .heic) || $0.conforms(to: .heif) }) {
            return [.jpeg, .png, .heic]
        }
        return []
    }
}
