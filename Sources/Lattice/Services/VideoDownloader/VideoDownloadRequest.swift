// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Darwin
import Foundation

enum VideoDownloadError: LocalizedError, Equatable {
    case invalidURL, unsupportedMetadata, missingTools, invalidOutput, timedOut
    case command(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return VideoDownloaderStrings.invalidURL
        case .unsupportedMetadata: return VideoDownloaderStrings.unsupportedMetadata
        case .missingTools: return VideoDownloaderStrings.missingTools
        case .invalidOutput: return VideoDownloaderStrings.invalidOutput
        case .timedOut: return VideoDownloaderStrings.timedOut
        case .command(let message): return message
        }
    }
}

struct VideoDownloadQuality: Identifiable, Equatable, Hashable, Sendable {
    let height: Int
    var isAudio: Bool { height == -1 }
    var isBest: Bool { height == 0 }

    var id: Int { height }
    var title: String {
        if isAudio { return VideoDownloaderStrings.audioQuality }
        if isBest { return VideoDownloaderStrings.bestQuality }
        return "\(height)p"
    }

    var containerTag: String {
        isAudio ? "M4A" : "MKV"
    }

    var format: String {
        if isAudio { return "ba/b" }
        if isBest { return "bv*+ba/b" }
        return "bv*[height<=\(height)]+ba/b[height<=\(height)]"
    }

    static let best = VideoDownloadQuality(height: 0)
    static let audio = VideoDownloadQuality(height: -1)
}

struct DownloadProgress: Equatable, Sendable {
    let fraction: Double
    let percentText: String
    let downloadedBytes: Int64?
    let totalBytes: Int64?
    let speedBytesPerSec: Double?
    let etaSeconds: Double?

    var formattedDetails: String {
        var parts: [String] = []
        if let downloaded = downloadedBytes, let total = totalBytes, total > 0 {
            let df = ByteCountFormatter()
            df.countStyle = .file
            parts.append("\(df.string(fromByteCount: downloaded)) of \(df.string(fromByteCount: total))")
        } else if let downloaded = downloadedBytes {
            let df = ByteCountFormatter()
            df.countStyle = .file
            parts.append(df.string(fromByteCount: downloaded))
        }

        if let speed = speedBytesPerSec, speed > 0 {
            let df = ByteCountFormatter()
            df.countStyle = .file
            parts.append("\(df.string(fromByteCount: Int64(speed)))/s")
        }

        if let eta = etaSeconds, eta > 0 {
            if eta < 60 {
                parts.append("\(Int(eta))s left")
            } else {
                let mins = Int(ceil(eta / 60))
                parts.append("\(mins) min left")
            }
        }

        return parts.joined(separator: " · ")
    }
}

enum VideoDownloadRequest {
    static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    static func validClipboardURL(read: () -> String? = { NSPasteboard.general.string(forType: .string) }) -> String? {
        guard let raw = read()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              !raw.contains(where: { $0.isWhitespace || $0.isNewline }),
              !raw.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            return nil
        }
        let candidate = raw.contains("://") ? raw : "https://" + raw
        guard let parts = URLComponents(string: candidate),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host,
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix("."),
              parts.user == nil, parts.password == nil else {
            return nil
        }
        return candidate
    }

    static func validatedURL(_ text: String) throws -> URL {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              let parts = URLComponents(string: text), ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              let url = parts.url else { throw VideoDownloadError.invalidURL }
        return url
    }

    static let common = ["--ignore-config", "--no-plugin-dirs", "--no-playlist", "--no-color",
                         "--socket-timeout", "20", "--retries", "2", "--no-cache-dir", "--no-write-comments"]

    static func metadataArguments(url: URL) -> [String] {
        common + ["--skip-download", "--dump-single-json", "--playlist-items", "1", "--", url.absoluteString]
    }

    static func downloadArguments(url: URL, quality: VideoDownloadQuality, staging: URL, ffmpeg: String) -> [String] {
        var args = common + ["--newline", "--progress", "--no-simulate", "--no-overwrites",
                             "--ffmpeg-location", ffmpeg]

        if quality.isAudio {
            args += ["--extract-audio", "--audio-format", "m4a", "--audio-quality", "0",
                     "--format", "bestaudio/b"]
        } else {
            args += ["--format", quality.format, "--merge-output-format", "mkv"]
        }

        args += [
            "--restrict-filenames", "--windows-filenames",
            "--paths", staging.path, "--output", "%(title).120B [%(id).60B].%(ext)s",
            "--progress-template", "download:LATTICE_PROGRESS:%(progress._percent_str)s|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.speed)s|%(progress.eta)s|%(progress.fragment_index)s|%(progress.fragment_count)s|%(progress.status)s|%(info.format_id)j",
            "--print", "before_dl:LATTICE_PARTS:{\"parts\":%(requested_formats.:.{format_id,filesize,filesize_approx}|[])j,\"single\":%(format_id)j}",
            "--print", "after_move:LATTICE_FILE:%(filepath)s", "--", url.absoluteString
        ]
        return args
    }

    static func progress(_ line: String) -> Double? {
        guard line.hasPrefix("LATTICE_PROGRESS:") else { return nil }
        let payload = line.dropFirst("LATTICE_PROGRESS:".count)
        let percentPart = payload.split(separator: "|").first ?? payload
        guard let percent = Double(percentPart.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)),
              percent.isFinite else { return nil }
        return min(1, max(0, percent / 100))
    }

    static func parseProgress(_ line: String) -> DownloadProgress? {
        guard let fraction = progress(line) else { return nil }
        let percentText = "\(Int(fraction * 100))%"
        let payload = String(line.dropFirst("LATTICE_PROGRESS:".count))
        let tokens = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)

        var downloaded: Int64? = nil
        var total: Int64? = nil
        var speed: Double? = nil
        var eta: Double? = nil

        if tokens.count >= 5 {
            downloaded = Int64(tokens[1])
            total = Int64(tokens[2])
            speed = Double(tokens[3])
            eta = Double(tokens[4])
        }

        return DownloadProgress(
            fraction: fraction,
            percentText: percentText,
            downloadedBytes: downloaded,
            totalBytes: total,
            speedBytesPerSec: speed,
            etaSeconds: eta
        )
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

    static func hasPlayableMedia(_ data: Data, isAudio: Bool) -> Bool {
        if !isAudio { return hasPlayableVideo(data) }
        struct Probe: Decodable {
            struct Stream: Decodable { var codec_type: String? }
            struct Format: Decodable { var duration: String? }
            var streams: [Stream]?
            var format: Format?
        }
        guard let probe = try? JSONDecoder().decode(Probe.self, from: data),
              let duration = probe.format?.duration.flatMap(Double.init), duration.isFinite, duration > 0 else { return false }
        return probe.streams?.contains { $0.codec_type == "audio" } == true
    }

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

    static func publish(_ source: URL, from staging: URL, to destination: URL) throws -> URL {
        let file = try validatedOutput(source, from: staging)
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
