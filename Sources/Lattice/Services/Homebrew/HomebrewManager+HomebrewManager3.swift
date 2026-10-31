// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Darwin
import Foundation

extension HomebrewManager {

    func scheduleCompletedOperationCleanup(result: HomebrewOperationResult,
                                                   targetID: String,
                                                   finishedAt: Date?) {
        completedOperationCleanup?.cancel()
        guard result != .running,
              let finishedAt else { return }
        let delay: TimeInterval
        let clearsWholeStatus: Bool
        switch result {
        case .succeeded:
            delay = 8
            clearsWholeStatus = true
        case .cancelled:
            delay = 6
            clearsWholeStatus = true
        case .failed, .needsTerminal:
            delay = 20
            clearsWholeStatus = false
        case .running:
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.operation == nil,
                  self.operationStatus?.targetID == targetID,
                  self.operationStatus?.finishedAt == finishedAt else { return }
            self.log = ""
            if clearsWholeStatus {
                self.terminalFallbackCommand = nil
                self.operationStatus = nil
            }
            self.completedOperationCleanup = nil
        }
        completedOperationCleanup = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// One click on the trust card: marks the tap as trusted for Homebrew
    /// and picks the interrupted work back up.
    func trustTapAndContinue() {
        guard let cancellation = readWork.begin(owner: .homebrew, isAvailable: { $0.isAvailable }) else { return }
        guard let tap = untrustedTap, !isTrustingTap,
              HomebrewCommandBuilder.isValidToken(tap),
              let brewPath = brewPath ?? detectBrewPath() else { return }
        isTrustingTap = true
        let retry = untrustedTapRetry
        run(HomebrewCommandBuilder.trustTap(brewPath: brewPath, tap: tap), cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled else { return }
                self.isTrustingTap = false
                guard status == 0 else {
                    self.errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return
                }
                self.clearUntrustedTap()
                retry?()
            }
        }
    }

    func presentUntrustedTap(_ tap: String, retry: @escaping () -> Void) {
        untrustedTap = tap
        untrustedTapRetry = retry
        errorMessage = nil
    }

    func clearUntrustedTap() {
        untrustedTap = nil
        untrustedTapRetry = nil
    }

    func detectBrewPath() -> String? {
        HomebrewCommandBuilder.candidatePaths.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    /// SIGTERM is cooperative. Escalate only when a command ignores it so a
    /// cancelled or timed-out operation cannot keep the serial queue forever.
    static func stop(_ process: Process, finished: DispatchSemaphore? = nil) {
        guard process.isRunning else { return }
        process.terminate()
        if let finished {
            if finished.wait(timeout: .now() + processTerminationGrace) == .timedOut,
               process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + processTerminationGrace)
            }
            return
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + processTerminationGrace) {
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
    }

    /// Called on `workQueue` only: the first `HomebrewEnvironment.forBrew` read
    /// waits on the login shell.
    static func makeProcess(_ command: HomebrewCommand) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.environment = HomebrewEnvironment.forBrew
        return process
    }

    func run(_ command: HomebrewCommand, cancellation: FeatureWorkCancellation,
             completion: @escaping (_ status: Int32, _ output: String) -> Void) {
        workQueue.async {
            let result = FeatureReadProcess.run(command.executable, command.arguments,
                timeout: Self.brewReadTimeout, environment: HomebrewEnvironment.forBrew,
                cancellation: cancellation)
            completion(result.status, result.output)
        }
    }

    func runStreaming(_ command: HomebrewCommand,
                              onOutput: @escaping (String) -> Void,
                              completion: @escaping (_ status: Int32, _ output: String) -> Void) {
        workQueue.async { [weak self] in
            let process = Self.makeProcess(command)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            var output = Data()
            var lastOutput = Date()
            let lock = NSLock()
            let drained = DispatchSemaphore(value: 0)
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    drained.signal()
                    return
                }
                lock.lock()
                output.append(data)
                lastOutput = Date()
                lock.unlock()
                if let chunk = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { onOutput(chunk) }
                }
            }
            let finished = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in finished.signal() }
            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                completion(-1, error.localizedDescription)
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.activeProcess = process
                if self.cancelRequested { Self.stop(process) }
            }
            while finished.wait(timeout: .now() + Self.brewSilenceTimeout) == .timedOut {
                lock.lock()
                let silence = Date().timeIntervalSince(lastOutput)
                lock.unlock()
                if silence >= Self.brewSilenceTimeout {
                    Self.stop(process, finished: finished)
                    break
                }
            }
            _ = drained.wait(timeout: .now() + 1)
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            lock.lock()
            let finalOutput = String(data: output, encoding: .utf8) ?? ""
            lock.unlock()
            completion(process.isRunning ? -1 : process.terminationStatus, finalOutput)
        }
    }

    func appendLog(_ text: String) {
        log.append(text)
    }

    func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
