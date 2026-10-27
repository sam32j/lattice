import Darwin
import Foundation

/// One operation owns its process group, output drains and cancellation.
final class VideoDownloadProcess: @unchecked Sendable {
    struct Output { let stdout: Data; let stderr: String }
    private let lock = NSLock()
    private var child: Process?
    private var cancelled = false
    private var groups: Set<pid_t> = []

    func cancel(immediately: Bool = false) {
        lock.lock(); cancelled = true; let process = child; let ownedGroups = groups; lock.unlock()
        for group in ownedGroups { kill(-group, immediately ? SIGKILL : SIGINT) }
        if let process, process.isRunning, !ownedGroups.contains(process.processIdentifier) {
            signal(process, immediately ? SIGKILL : SIGINT)
        }
        if immediately { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) { [self] in
            // Group lifetime is independent of the leader's lifetime. A merger
            // may still be alive after yt-dlp has already handled SIGINT.
            for group in ownedGroups { kill(-group, SIGKILL) }
            if let process, process.isRunning, !ownedGroups.contains(process.processIdentifier) { signal(process, SIGKILL) }
        }
    }

    private var paused = false
    var isPaused: Bool { lock.lock(); defer { lock.unlock() }; return paused }

    func pause() {
        lock.lock()
        guard !cancelled, !paused else { lock.unlock(); return }
        paused = true
        let ownedGroups = groups
        let process = child
        lock.unlock()
        for group in ownedGroups { kill(-group, SIGSTOP) }
        if let process, process.isRunning, !ownedGroups.contains(process.processIdentifier) {
            kill(process.processIdentifier, SIGSTOP)
        }
    }

    func resume() {
        lock.lock()
        guard !cancelled, paused else { lock.unlock(); return }
        paused = false
        let ownedGroups = groups
        let process = child
        lock.unlock()
        for group in ownedGroups { kill(-group, SIGCONT) }
        if let process, process.isRunning, !ownedGroups.contains(process.processIdentifier) {
            kill(process.processIdentifier, SIGCONT)
        }
    }

    private func signal(_ process: Process, _ signal: Int32) {
        let pid = process.processIdentifier
        // Foundation starts Process in its own group on macOS. Check before
        // signalling descendants so the app's own process group is never hit.
        if getpgid(pid) == pid { kill(-pid, signal) }
        else { kill(pid, signal) }
    }

    func run(executable: String, arguments: [String], environment: [String: String],
             timeout: TimeInterval, stdoutLimit: Int = 64_000_000,
             line: ((String) -> Void)? = nil) throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let out = Pipe(), err = Pipe()
        process.standardOutput = out; process.standardError = err
        let output = DownloadOutputBuffer(limit: stdoutLimit, line: line)
        let errors = DownloadOutputBuffer(limit: 65_536, line: nil)
        let drained = DispatchGroup()
        func drain(_ pipe: Pipe, to buffer: DownloadOutputBuffer) {
            drained.enter()
            DispatchQueue.global(qos: .utility).async {
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    buffer.append(data)
                }
                try? pipe.fileHandleForReading.close()
                drained.leave()
            }
        }
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        lock.lock()
        guard !cancelled, child == nil else { lock.unlock(); throw CancellationError() }
        do {
            try process.run(); child = process
            if getpgid(process.processIdentifier) == process.processIdentifier { groups.insert(process.processIdentifier) }
            lock.unlock()
        }
        catch { lock.unlock(); throw error }
        try? out.fileHandleForWriting.close(); try? err.fileHandleForWriting.close()
        drain(out, to: output); drain(err, to: errors)
        let timedOut = exited.wait(timeout: .now() + timeout) == .timedOut
        if timedOut { signal(process, SIGKILL); _ = exited.wait(timeout: .now() + 3) }
        // Owned descendants may keep pipes open; never leave a UI job waiting forever.
        let finishedDrain = drained.wait(timeout: .now() + 3) == .success
        lock.lock(); child = nil; let wasCancelled = cancelled; lock.unlock()
        if wasCancelled { cancel(immediately: true); throw CancellationError() }
        if !finishedDrain {
            // A successful leader exit does not mean descendants have exited.
            // Stop pipe holders while this job still owns their process group.
            lock.lock(); let ownedGroups = groups; lock.unlock()
            for group in ownedGroups { kill(-group, SIGKILL) }
            _ = drained.wait(timeout: .now() + 1)
        }
        lock.lock(); groups.remove(process.processIdentifier); lock.unlock()
        if timedOut { throw VideoDownloadError.timedOut }
        guard finishedDrain, !output.overflowed else { throw VideoDownloadError.command("The tool returned too much data or did not close its output. Try another link.") }
        let errorText = String(decoding: errors.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stdoutText = String(decoding: output.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            let combined: String
            if !errorText.isEmpty && !stdoutText.isEmpty {
                combined = stdoutText + "\n" + errorText
            } else if !errorText.isEmpty {
                combined = errorText
            } else if !stdoutText.isEmpty {
                combined = stdoutText
            } else {
                combined = "The download tool failed. Please check the link."
            }
            throw VideoDownloadError.command(String(combined.suffix(8000)))
        }
        return Output(stdout: output.data, stderr: errorText)
    }
}

private final class DownloadOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var stored = Data(), pending = Data()
    private var exceeded = false
    private let line: ((String) -> Void)?
    init(limit: Int, line: ((String) -> Void)?) { self.limit = limit; self.line = line }
    var data: Data { lock.lock(); defer { lock.unlock() }; return stored }
    var overflowed: Bool { lock.lock(); defer { lock.unlock() }; return exceeded }
    func append(_ chunk: Data) {
        lock.lock()
        if line != nil {
            // When streaming lines (e.g. download progress), stored is only needed for trailing markers (e.g. LATTICE_FILE:).
            // Keep a rolling buffer of the latest output up to limit, and never overflow from streaming progress lines.
            stored.append(chunk)
            if stored.count > limit {
                let excess = stored.count - limit
                stored.removeSubrange(..<excess)
            }
        } else {
            if stored.count + chunk.count > limit { exceeded = true }
            stored.append(chunk.prefix(max(0, limit - stored.count)))
        }

        guard let line else { lock.unlock(); return }
        pending.append(chunk)
        var lines: [String] = []
        // Handle both \n (10) and \r (13) delimiters so terminal progress updates don't pile up in pending
        while let idx = pending.firstIndex(where: { $0 == 10 || $0 == 13 }) {
            let lineData = pending[..<idx]
            if !lineData.isEmpty {
                lines.append(String(decoding: lineData, as: UTF8.self))
            }
            if pending[idx] == 13 && pending.indices.contains(idx + 1) && pending[idx + 1] == 10 {
                pending.removeSubrange(...(idx + 1))
            } else {
                pending.removeSubrange(...idx)
            }
        }
        if pending.count > 131_072 {
            pending.removeAll()
        }
        lock.unlock()
        lines.forEach(line)
    }
}
