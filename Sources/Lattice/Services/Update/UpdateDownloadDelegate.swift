// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine


/// Writes a response to a scratch file and abandons it once it passes
/// `byteLimit`, so a body that never ends cannot fill the disk. Shared by the
/// app update download and the What's New showcase video.
final class BoundedUpdateDownloadDelegate: NSObject, URLSessionDataDelegate {
    private let byteLimit: Int64
    private let progress: (Int64, Int64?) -> Void
    private let completion: (URL?, URLResponse?, Error?) -> Void
    private let fileURL: URL
    private let fileHandle: FileHandle
    private var response: URLResponse?
    private var responseExpectedBytes: Int64?
    private var receivedBytes: Int64 = 0
    private var completed = false
    private var exceededLimit = false
    private var writeError: Error?

    init(byteLimit: Int64,
         progress: @escaping (Int64, Int64?) -> Void,
         completion: @escaping (URL?, URLResponse?, Error?) -> Void) throws {
        self.byteLimit = byteLimit
        self.progress = progress
        self.completion = completion
        let temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Lattice-update-\(UUID().uuidString).download")
        fileURL = temporaryFileURL
        guard FileManager.default.createFile(atPath: temporaryFileURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            fileHandle = try FileHandle(forWritingTo: temporaryFileURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryFileURL)
            throw error
        }
    }

    deinit {
        try? fileHandle.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        responseExpectedBytes = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        guard writeError == nil, !exceededLimit else { return }
        let chunkBytes = Int64(data.count)
        guard chunkBytes <= byteLimit - receivedBytes else {
            exceededLimit = true
            dataTask.cancel()
            return
        }
        do {
            try fileHandle.write(contentsOf: data)
            receivedBytes += chunkBytes
            progress(receivedBytes, responseExpectedBytes)
        } catch {
            writeError = error
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let closeError: Error?
        do {
            try fileHandle.close()
            closeError = nil
        } catch {
            closeError = error
        }
        if let writeError {
            complete(location: nil, response: response, error: writeError)
        } else if exceededLimit {
            complete(location: nil, response: response, error: POSIXError(.EFBIG))
        } else if let error {
            complete(location: nil, response: response, error: error)
        } else if let closeError {
            complete(location: nil, response: response, error: closeError)
        } else {
            complete(location: fileURL, response: response, error: nil)
        }
    }

    private func complete(location: URL?, response: URLResponse?, error: Error?) {
        guard !completed else { return }
        completed = true
        if location == nil {
            try? FileManager.default.removeItem(at: fileURL)
        }
        completion(location, response, error)
    }
}
