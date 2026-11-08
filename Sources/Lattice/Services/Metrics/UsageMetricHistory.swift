// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Retains the recent readings for compact sparklines and their timestamps for
/// detail charts with a fixed time axis.
struct UsageMetricHistory {
    struct Sample {
        let value: Double
        let time: ContinuousClock.Instant
    }

    struct Point: Equatable {
        let value: Double
        let position: Double
    }

    static let windowSeconds = 60
    static let hourSeconds = 3600
    private let capacity: Int
    private let minimumInterval: Duration
    private var samples: [Sample] = []

    init(capacity: Int, minimumInterval: Duration = .zero) {
        self.capacity = max(1, capacity)
        self.minimumInterval = minimumInterval
    }

    mutating func push(_ value: Double, at time: ContinuousClock.Instant) {
        if let last = samples.last, last.time.duration(to: time) < minimumInterval { return }
        samples.append(Sample(value: value, time: time))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    func publishedSamples(whileVisible visible: Bool) -> [Sample] {
        visible ? samples : []
    }

    static func window(_ samples: [Sample], endingAt now: ContinuousClock.Instant,
                       duration: Duration = .seconds(windowSeconds)) -> [Point] {
        let start = now - duration
        return samples.compactMap { sample in
            guard sample.time >= start, sample.time <= now else { return nil }
            let position = start.duration(to: sample.time) / duration
            return Point(value: sample.value, position: position)
        }
    }

    static func segments(_ points: [Point], duration: Duration, maximumGap: Duration) -> [[Point]] {
        let limit = maximumGap / duration
        var segments: [[Point]] = []
        var current: [Point] = []
        for point in points {
            if let last = current.last, point.position - last.position > limit {
                segments.append(current)
                current = []
            }
            current.append(point)
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }
}
