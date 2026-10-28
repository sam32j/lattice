// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

struct VideoDownloadInfo: Equatable, Sendable {
    let title: String
    let creator: String
    let duration: Double?
    let thumbnailURL: URL?
    let sourceLabel: String
    let qualities: [VideoDownloadQuality]
    let hasAudio: Bool
    let estimatedSizeBytes: [Int: Int64]

    var formattedDuration: String? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        return VideoDownloadRequest.formatDuration(duration)
    }

    func estimatedSizeFormatted(for quality: VideoDownloadQuality) -> String? {
        let key = quality.isBest ? (qualities.first?.height ?? 0) : quality.height
        guard let bytes = estimatedSizeBytes[key], bytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "~\(formatter.string(fromByteCount: bytes))"
    }

    static func decode(_ data: Data) throws -> Self {
        struct Format: Decodable {
            var height: Int?
            var vcodec: String?
            var acodec: String?
            var has_drm: Bool?
            var filesize: Int64?
            var filesize_approx: Int64?
            var tbr: Double?
        }
        struct Info: Decodable {
            var title: String?
            var uploader: String?
            var duration: Double?
            var thumbnail: String?
            var extractor: String?
            var extractor_key: String?
            var formats: [Format]?
            var _type: String?
            var is_live: Bool?
        }
        let info = try JSONDecoder().decode(Info.self, from: data)
        guard info._type != "playlist", info._type != "multi_video", info.is_live != true,
              let title = info.title, !title.isEmpty else {
            throw VideoDownloadError.unsupportedMetadata
        }

        let formats = info.formats ?? []
        let availableHeights = Set(formats.compactMap { format -> Int? in
            guard format.has_drm != true, let codec = format.vcodec, codec != "none",
                  let height = format.height, height > 0, height <= 16384 else { return nil }
            return height
        }).sorted(by: >)

        guard !availableHeights.isEmpty else { throw VideoDownloadError.unsupportedMetadata }

        // Compute size estimates
        var sizeMap: [Int: Int64] = [:]
        let duration = info.duration ?? 0
        for format in formats {
            guard format.has_drm != true else { continue }
            let size = format.filesize ?? format.filesize_approx ?? (format.tbr.flatMap { tbr in
                guard duration > 0, duration.isFinite, tbr > 0, tbr.isFinite else { return nil }
                let bytes = tbr * 125 * duration
                guard bytes > 0, bytes.isFinite, bytes <= Double(Int64.max) else { return nil }
                return Int64(bytes)
            })
            if let size, size > 0 {
                if let h = format.height, h > 0 {
                    sizeMap[h] = max(sizeMap[h] ?? 0, size)
                }
                if format.vcodec == "none" && format.acodec != "none" {
                    sizeMap[-1] = max(sizeMap[-1] ?? 0, size)
                }
            }
        }
        if let topHeight = availableHeights.first, let topSize = sizeMap[topHeight] {
            sizeMap[0] = topSize
        }

        let hasAudio = formats.contains(where: { $0.acodec != nil && $0.acodec != "none" })
        let source = (info.extractor_key ?? info.extractor ?? "WEB")
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .uppercased()

        return Self(
            title: title,
            creator: info.uploader ?? "",
            duration: info.duration,
            thumbnailURL: info.thumbnail.flatMap { raw -> URL? in
                var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.hasPrefix("http://") {
                    text = "https://" + text.dropFirst("http://".count)
                }
                return URL(string: text)
            },
            sourceLabel: source,
            qualities: availableHeights.map { VideoDownloadQuality(height: $0) },
            hasAudio: hasAudio,
            estimatedSizeBytes: sizeMap
        )
    }
}
