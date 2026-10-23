import Darwin
import Foundation

enum VideoDownloadError: LocalizedError {
    case invalidURL, unsupportedMetadata, missingTools, invalidOutput, timedOut
    case command(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Paste a complete http:// or https:// video link without a username or password."
        case .unsupportedMetadata: return "No downloadable video was found. Use a single video link, not a playlist or live stream."
        case .missingTools: return "Install the missing tools below, then check again."
        case .invalidOutput: return "The download did not produce a complete video file. Try another quality or link."
        case .timedOut: return "The operation took too long. Check your connection and try again."
        case .command(let message): return message
        }
    }
}

struct VideoDownloadQuality: Identifiable, Equatable {
    let height: Int
    var id: Int { height }
    var title: String { "\(height)p" }
    var format: String { "bv*[height<=\(height)]+ba/b[height<=\(height)]" }
}

struct VideoDownloadInfo: Equatable {
    let title: String
    let creator: String
    let duration: Double?
    let qualities: [VideoDownloadQuality]

    static func decode(_ data: Data) throws -> Self {
        struct Format: Decodable {
            var height: Int?
            var vcodec: String?
            var has_drm: Bool?
        }
        struct Info: Decodable {
            var title: String?
            var uploader: String?
            var duration: Double?
            var formats: [Format]?
            var _type: String?
            var is_live: Bool?
        }
        let info = try JSONDecoder().decode(Info.self, from: data)
        let heights = Set((info.formats ?? []).compactMap { format -> Int? in
            guard format.has_drm != true, let codec = format.vcodec, codec != "none",
                  let height = format.height, height > 0, height <= 16384 else { return nil }
            return height
        }).sorted(by: >)
        guard info._type != "playlist", info._type != "multi_video", info.is_live != true,
              let title = info.title, !title.isEmpty, !heights.isEmpty else { throw VideoDownloadError.unsupportedMetadata }
        return Self(title: title, creator: info.uploader ?? "", duration: info.duration,
                    qualities: heights.map { VideoDownloadQuality(height: $0) })
    }
}

enum VideoDownloadRequest {
    static func validatedURL(_ text: String) throws -> URL {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              let parts = URLComponents(string: text), ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              let url = parts.url else { throw VideoDownloadError.invalidURL }
        return url
    }

    static let common = ["--ignore-config", "--no-plugin-dirs", "--no-playlist", "--no-color",
                         "--socket-timeout", "20", "--retries", "2", "--no-cache-dir"]

    static func metadataArguments(url: URL) -> [String] {
        common + ["--skip-download", "--dump-single-json", "--", url.absoluteString]
    }

    static func downloadArguments(url: URL, quality: VideoDownloadQuality, staging: URL, ffmpeg: String) -> [String] {
        common + ["--newline", "--progress", "--no-simulate", "--no-overwrites",
                  "--ffmpeg-location", ffmpeg, "--format", quality.format,
                  "--merge-output-format", "mkv", "--restrict-filenames", "--windows-filenames",
                  "--paths", staging.path, "--output", "%(title).120B [%(id).60B].%(ext)s",
                  "--progress-template", "download:LATTICE_PROGRESS:%(progress._percent_str)s",
                  "--print", "after_move:LATTICE_FILE:%(filepath)s", "--", url.absoluteString]
    }

    static func progress(_ line: String) -> Double? {
        guard line.hasPrefix("LATTICE_PROGRESS:"),
              let percent = Double(line.dropFirst("LATTICE_PROGRESS:".count).replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)),
              percent.isFinite else { return nil }
        return min(1, max(0, percent / 100))
    }

    static func hasPlayableVideo(_ data: Data) -> Bool {
        struct Probe: Decodable {
            struct Stream: Decodable { var codec_type: String?; var width: Int?; var height: Int? }
            struct Format: Decodable { var duration: String? }
            var streams: [Stream]?
            var format: Format?
        }
        guard let probe = try? JSONDecoder().decode(Probe.self, from: data),
              let duration = probe.format?.duration.flatMap(Double.init), duration.isFinite, duration > 0 else { return false }
        return probe.streams?.contains { $0.codec_type == "video" && ($0.width ?? 0) > 0 && ($0.height ?? 0) > 0 } == true
    }

    /// Check before probing too: a tool-reported path is not permission to
    /// open an unrelated local file or a remote media protocol.
    static func validatedOutput(_ source: URL, from staging: URL) throws -> URL {
        let file = source.resolvingSymlinksInPath().standardizedFileURL
        let root = staging.resolvingSymlinksInPath().standardizedFileURL
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard file.deletingLastPathComponent() == root, values.isRegularFile == true,
              (values.fileSize ?? 0) > 0, !["part", "ytdl", "temp"].contains(file.pathExtension) else {
            throw VideoDownloadError.invalidOutput
        }
        return file
    }

    /// Never trust a CLI-reported path outside our unique staging directory.
    static func publish(_ source: URL, from staging: URL, to destination: URL) throws -> URL {
        let file = try validatedOutput(source, from: staging)
        // Staging is on the chosen volume. Exclusive rename is atomic and does
        // not copy a multi-gigabyte file on the UI thread at publication time.
        for index in 1...1000 {
            let name = index == 1 ? file.lastPathComponent
                : "\(file.deletingPathExtension().lastPathComponent) (\(index)).\(file.pathExtension)"
            let output = destination.appendingPathComponent(name)
            if renamex_np(file.path, output.path, UInt32(RENAME_EXCL)) == 0 { return output }
            if errno != EEXIST { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        }
        throw VideoDownloadError.command("Too many files share this name. Choose another folder.")
    }
}
