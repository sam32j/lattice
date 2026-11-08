// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// A user-triggered internet speed test: latency, then download, then upload,
/// using Cloudflare's public speed endpoints (the same backend speed.cloudflare.com
/// uses). Time-boxed so it stays bounded on any connection. No third-party
/// framework; no user data ever leaves the machine (the upload body is zeros).
///
/// All mutable state is touched only on the session's serial delegate queue;
/// published values are pushed to the main thread.
final class SpeedTest: NSObject, ObservableObject {
    static let shared = SpeedTest()

    typealias Clock = () -> TimeInterval
    typealias TimeBoxScheduler = (OperationQueue, TimeInterval, @escaping () -> Void) -> () -> Void

    enum Phase: Equatable {
        case idle, latency, download, upload, done
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var latencyMs: Double?
    @Published private(set) var downloadMbps: Double?
    @Published private(set) var uploadMbps: Double?
    @Published private(set) var liveMbps: Double = 0
    @Published private(set) var sparklinePoints: [Double] = [0]
    @Published private(set) var downloadPoints: [Double] = [0]
    @Published private(set) var uploadPoints: [Double] = [0]
    @Published private(set) var phaseProgress: Double = 0

    var isRunning: Bool {
        switch phase { case .latency, .download, .upload: return true; default: return false }
    }

    private enum Kind { case none, download, upload }

    private let host = "https://speed.cloudflare.com"
    private let sampleSeconds: TimeInterval
    private let clock: Clock
    private let scheduleTimeBox: TimeBoxScheduler
    // Cloudflare's __down caps the size just under 100 MB (100 MB+ returns ~nothing),
    // so request under that and loop chunks back-to-back until the time box — that
    // keeps a fast link's pipe full for a full measurement window.
    private let downloadBytes = 90_000_000
    private let uploadBytes = 100_000_000

    private let queue = OperationQueue()
    private var session: URLSession!
    private var task: URLSessionTask?
    private var kind: Kind = .none           // touched only on `queue`
    private var transferred: Int64 = 0       // touched only on `queue`
    private var startedAt: TimeInterval = 0
    private var finished = false
    private var generation = 0
    private var cancelTimeBox: (() -> Void)?
    private var sampleTimer: DispatchSourceTimer?

    init(configuration: URLSessionConfiguration = .ephemeral, sampleSeconds: TimeInterval = 5,
         clock: @escaping Clock = { ProcessInfo.processInfo.systemUptime },
         scheduleTimeBox: @escaping TimeBoxScheduler = { queue, delay, action in
             let work = DispatchWorkItem { queue.addOperation(action) }
             DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: work)
             return { work.cancel() }
         }) {
        self.sampleSeconds = sampleSeconds
        self.clock = clock
        self.scheduleTimeBox = scheduleTimeBox
        super.init()
        queue.maxConcurrentOperationCount = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }

    func start() {
        guard !isRunning else { return }
        stopLiveSampling()
        latencyMs = nil; downloadMbps = nil; uploadMbps = nil
        liveMbps = 0
        sparklinePoints = [0]
        downloadPoints = [0]
        uploadPoints = [0]
        phaseProgress = 0
        setPhase(.latency)
        queue.addOperation { [weak self] in
            guard let self else { return }
            self.generation += 1
            self.measureLatency(remaining: 5, best: .greatestFiniteMagnitude)
        }
    }

    func cancel() {
        stopLiveSampling()
        queue.addOperation { [weak self] in
            guard let self else { return }
            self.generation += 1
            self.cancelTimeBox?(); self.cancelTimeBox = nil
            self.task?.cancel(); self.task = nil
            self.kind = .none
            self.finished = true
            DispatchQueue.main.async {
                self.liveMbps = 0
                self.phaseProgress = 0
            }
            self.setPhase(.idle)   // inside the op, so it orders after any pending transition
        }
    }

    private func setPhase(_ phase: Phase) {
        DispatchQueue.main.async { self.phase = phase }
    }

    // MARK: - Latency (completion-handler tasks bypass the byte-counting delegate)

    private func measureLatency(remaining: Int, best: Double) {
        guard remaining > 0 else {
            let value = best == .greatestFiniteMagnitude ? nil : best
            DispatchQueue.main.async {
                self.latencyMs = value
                self.phaseProgress = 0.15
            }
            startTransfer(.download)
            return
        }
        let url = URL(string: "\(host)/__down?bytes=0")!
        let started = clock()
        let generation = self.generation
        let progress = min(0.15, Double(5 - remaining) * 0.03)
        DispatchQueue.main.async { self.phaseProgress = progress }
        task = session.dataTask(with: url) { [weak self] _, response, error in
            guard let self else { return }
            let rtt = (self.clock() - started) * 1000
            // Continue on the delegate queue so the transfer phase's `kind` is set
            // there too — otherwise the byte-counting delegate could miss it.
            self.queue.addOperation {
                guard self.generation == generation else { return }
                guard error == nil, Self.isSuccessful(response) else {
                    self.fail(error ?? URLError(.badServerResponse))
                    return
                }
                self.measureLatency(remaining: remaining - 1, best: min(best, rtt))
            }
        }
        task?.resume()
    }

    // MARK: - Download / upload (delegate tasks), time-boxed

    private func startTransfer(_ transfer: Kind) {
        generation += 1
        kind = transfer
        transferred = 0
        finished = false
        setPhase(transfer == .download ? .download : .upload)
        startedAt = clock()
        startLiveSampling(for: transfer)

        let generation = self.generation
        cancelTimeBox?()   // defensive: never leave a previous time box armed
        cancelTimeBox = scheduleTimeBox(queue, sampleSeconds) { [weak self] in
            guard let self, self.generation == generation else { return }
            self.finishTransfer(timedOut: true)
        }
        beginChunk()
    }

    /// Starts one transfer. Download loops these (each capped under Cloudflare's
    /// limit) until the time box; upload is a single body.
    private func beginChunk() {
        guard !finished else { return }
        let task: URLSessionTask
        if kind == .download {
            task = session.dataTask(with: URL(string: "\(host)/__down?bytes=\(downloadBytes)")!)
        } else {
            var request = URLRequest(url: URL(string: "\(host)/__up")!)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            task = session.uploadTask(with: request, from: Data(count: uploadBytes))
        }
        self.task = task
        task.resume()
    }

    private func finishTransfer(timedOut: Bool) {
        guard !finished else { return }
        finished = true
        stopLiveSampling()
        cancelTimeBox?(); cancelTimeBox = nil

        let elapsed = clock() - startedAt
        let bytes = transferred
        if timedOut { task?.cancel() }
        task = nil
        let finishedKind = kind
        kind = .none

        let mbps = elapsed > 0 ? max(0, Double(bytes) * 8 / elapsed / 1_000_000) : 0
        DispatchQueue.main.async {
            if finishedKind == .download {
                self.downloadMbps = mbps
                self.liveMbps = mbps
                self.phaseProgress = 0.65
            } else {
                self.uploadMbps = mbps
                self.liveMbps = mbps
                self.phaseProgress = 1.0
            }
        }

        if finishedKind == .download {
            startTransfer(.upload)
        } else {
            setPhase(.done)
        }
    }

    private func startLiveSampling(for transfer: Kind) {
        stopLiveSampling()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 0.08, repeating: 0.08)
        let generation = self.generation
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.queue.addOperation {
                guard self.generation == generation, !self.finished, self.kind == transfer else { return }
                let elapsed = self.clock() - self.startedAt
                guard elapsed > 0.05 else { return }
                let currentBytes = self.transferred
                let currentMbps = Double(currentBytes) * 8.0 / elapsed / 1_000_000.0
                let fraction = min(1.0, max(0.0, elapsed / self.sampleSeconds))
                let baseProgress = transfer == .download ? 0.15 : 0.65
                let scaleProgress = transfer == .download ? 0.50 : 0.35
                let totalProgress = baseProgress + fraction * scaleProgress
                DispatchQueue.main.async {
                    self.liveMbps = currentMbps
                    self.phaseProgress = totalProgress
                    self.sparklinePoints.append(currentMbps)
                    if self.sparklinePoints.count > 60 {
                        self.sparklinePoints.removeFirst()
                    }
                    if transfer == .download {
                        self.downloadPoints.append(currentMbps)
                        if self.downloadPoints.count > 60 {
                            self.downloadPoints.removeFirst()
                        }
                    } else if transfer == .upload {
                        self.uploadPoints.append(currentMbps)
                        if self.uploadPoints.count > 60 {
                            self.uploadPoints.removeFirst()
                        }
                    }
                }
            }
        }
        sampleTimer = timer
        timer.resume()
    }

    private func stopLiveSampling() {
        sampleTimer?.cancel()
        sampleTimer = nil
    }

    private static func isSuccessful(_ response: URLResponse?) -> Bool {
        guard let response = response as? HTTPURLResponse else { return false }
        return (200...299).contains(response.statusCode)
    }

    private func fail(_ error: Error) {
        generation += 1
        finished = true
        stopLiveSampling()
        cancelTimeBox?(); cancelTimeBox = nil
        task?.cancel(); task = nil
        kind = .none
        DispatchQueue.main.async {
            self.liveMbps = 0
        }
        setPhase(.failed(error.localizedDescription))
    }
}

extension SpeedTest: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard dataTask === task, kind != .none, !finished else {
            completionHandler(.cancel)
            return
        }
        guard Self.isSuccessful(response) else {
            fail(URLError(.badServerResponse))
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if dataTask === task, kind == .download { transferred += Int64(data.count) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        if task === self.task, kind == .upload { transferred = totalBytesSent }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Ignore a stale completion from a task we already moved past (e.g. the
        // download chunk the time box just cancelled, arriving after upload began).
        guard task === self.task, kind != .none else { return }
        if let error = error as NSError?, error.code != NSURLErrorCancelled, transferred == 0 {
            fail(error)
            return
        }
        if kind == .download, !finished {
            beginChunk()   // keep the pipe full until the time box
        } else {
            finishTransfer(timedOut: false)
        }
    }
}
