// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// One download's transfer progress. Stream weights are fixed before downloading;
/// HLS fragment counts take precedence over fluctuating byte-size estimates.
struct VideoDownloadProgressTracker {
    private struct Part: Decodable {
        let format_id: String
        var filesize: Int64?
        var filesize_approx: Int64?
    }
    private struct Plan: Decodable {
        let parts: [Part]
        let single: String
    }
    private struct Sample {
        var fraction = 0.0
        var bytes: Int64?
        var total: Int64?
        var finished = false
    }
    private var parts: [Part] = []
    private var weights: [String: Double] = [:]
    private var samples: [String: Sample] = [:]
    private(set) var isFinishing = false

    mutating func consume(_ line: String) -> DownloadProgress? {
        if line.hasPrefix("LATTICE_PARTS:") {
            guard samples.isEmpty else { return nil }
            let data = Data(line.dropFirst("LATTICE_PARTS:".count).utf8)
            let decoded: [Part]
            if let plan = try? JSONDecoder().decode(Plan.self, from: data) {
                decoded = plan.parts.isEmpty ? [Part(format_id: plan.single)] : plan.parts
            } else if let list = try? JSONDecoder().decode([Part].self, from: data) {
                decoded = list
            } else if let id = try? JSONDecoder().decode(String.self, from: data) {
                decoded = [Part(format_id: id)]
            } else { return nil }
            var seen = Set<String>()
            parts = decoded.filter { !$0.format_id.isEmpty && seen.insert($0.format_id).inserted }
            let sizes = parts.map { positive($0.filesize) ?? positive($0.filesize_approx) }
            let allKnown = sizes.allSatisfy { $0 != nil }
            weights = Dictionary(uniqueKeysWithValues: parts.enumerated().map {
                ($0.element.format_id, allKnown ? Double(sizes[$0.offset]!) : 1)
            })
            return nil
        }
        guard line.hasPrefix("LATTICE_PROGRESS:") else { return nil }
        let tokens = line.dropFirst("LATTICE_PROGRESS:".count)
            .split(separator: "|", maxSplits: 8, omittingEmptySubsequences: false).map(String.init)
        let id: String
        if tokens.count == 9 {
            guard let parsed = try? JSONDecoder().decode(String.self, from: Data(tokens[8].utf8)) else { return nil }
            id = parsed
            guard weights[id] != nil else { return nil }
        } else if tokens.count == 1 || tokens.count == 5 {
            id = "legacy"
            if parts.isEmpty { parts = [Part(format_id: id)]; weights = [id: 1] }
            guard weights[id] != nil else { return nil }
        } else { return nil }
        func number(_ index: Int) -> Double? {
            guard tokens.indices.contains(index), let value = Double(tokens[index]), value.isFinite, value >= 0 else { return nil }
            return value
        }
        func bytes(_ index: Int) -> Int64? {
            guard tokens.indices.contains(index), let value = Int64(tokens[index]), value >= 0 else { return nil }
            return value
        }
        let finished = tokens.count == 9 && tokens[7] == "finished"
        let raw: Double
        if finished {
            raw = 1
        } else if let index = number(5), let count = number(6), count > 0 {
            raw = index / count
        } else if let downloaded = bytes(1), let total = positive(bytes(2)) {
            raw = Double(downloaded) / Double(total)
        } else if let value = Double(tokens[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)), value.isFinite {
            raw = value / 100
        } else { return nil }
        var sample = samples[id] ?? Sample()
        sample.fraction = max(sample.fraction, min(1, max(0, raw)))
        if let value = bytes(1) { sample.bytes = max(sample.bytes ?? 0, value) }
        if let value = positive(bytes(2)) { sample.total = value }
        sample.finished = sample.finished || finished
        samples[id] = sample
        isFinishing = parts.allSatisfy { samples[$0.format_id]?.finished == true }
        let weight = weights.values.reduce(0, +)
        guard weight > 0 else { return nil }
        let fraction = min(0.99, weights.reduce(0) { $0 + $1.value * (samples[$1.key]?.fraction ?? 0) } / weight)
        let downloaded = sum(samples.values.compactMap(\.bytes))
        let totals = parts.map { samples[$0.format_id]?.total ?? positive($0.filesize) }
        let total = totals.allSatisfy { $0 != nil } ? sum(totals.compactMap { $0 }) : nil
        let remaining = parts.filter { samples[$0.format_id]?.finished != true }.count
        return DownloadProgress(fraction: fraction, percentText: "\(Int(fraction * 100))%",
            downloadedBytes: downloaded, totalBytes: total, speedBytesPerSec: number(3),
            etaSeconds: remaining == 1 && !sample.finished ? number(4) : nil)
    }

    private func positive(_ value: Int64?) -> Int64? { value.flatMap { $0 > 0 ? $0 : nil } }
    private func sum(_ values: [Int64]) -> Int64? {
        guard !values.isEmpty else { return nil }
        var total: Int64 = 0
        for value in values {
            let result = total.addingReportingOverflow(value)
            guard !result.overflow else { return nil }
            total = result.partialValue
        }
        return total
    }
}
