import Darwin
import Foundation
import UniformTypeIdentifiers

enum FileOutputSupport {
    private static let maxFilenameBytes = 255
    static func outputURL(for inputURL: URL, suffix: String, fileExtension: String) -> URL {
        let directory = inputURL.deletingLastPathComponent()
        let base = visibleOutputBaseName(for: inputURL)
        return outputURL(in: directory, baseName: "\(base)\(suffix)", fileExtension: fileExtension)
    }


    static func outputURL(in directory: URL, baseName: String, fileExtension: String) -> URL {
        directory
            .appendingPathComponent(sanitizedFileBaseName(baseName,
                                                          fileExtension: fileExtension,
                                                          uniquenessSuffixByteReservation: 4))
            .appendingPathExtension(fileExtension)
    }


    static func visibleOutputBaseName(for inputURL: URL) -> String {
        let raw = inputURL.deletingPathExtension().lastPathComponent
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = trimmed.drop { $0 == "." }
        return visible.isEmpty ? "Output" : String(visible)
    }


    static func uniqueOutputURL(for inputURL: URL, suffix: String, fileExtension: String,
                                fileManager: FileManager = .default) -> URL {
        let candidate = outputURL(for: inputURL, suffix: suffix, fileExtension: fileExtension)
        return uniqueOutputURL(candidate: candidate, fileManager: fileManager)
    }


    static func uniqueOutputURL(in directory: URL, baseName: String, fileExtension: String,
                                reservedPaths: Set<String> = [],
                                fileManager: FileManager = .default) -> URL {
        uniqueOutputURL(candidate: outputURL(in: directory, baseName: baseName, fileExtension: fileExtension),
                        reservedPaths: reservedPaths,
                        fileManager: fileManager)
    }


    static func sanitizedFileBaseName(_ value: String,
                                      fileExtension: String = "",
                                      uniquenessSuffixByteReservation: Int = 0) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\\0")
            .union(.newlines)
            .union(.controlCharacters)
        let parts = value.components(separatedBy: invalid)
        let clean = parts.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".- "))
        let visible = clean.isEmpty ? "Output" : clean
        let extensionBytes = fileExtension.isEmpty ? 0 : fileExtension.utf8.count + 1
        let byteLimit = max(1, maxFilenameBytes - extensionBytes - max(0, uniquenessSuffixByteReservation))
        guard visible.utf8.count > byteLimit else { return visible }
        let shortened = prefix(visible, maxUTF8Bytes: byteLimit)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".- "))
        return shortened.isEmpty ? "Output" : shortened
    }


    private static func uniqueOutputURL(candidate: URL,
                                        reservedPaths: Set<String> = [],
                                        fileManager: FileManager = .default) -> URL {
        guard !reservedPaths.contains(candidate.standardizedFileURL.path),
              !fileManager.fileExists(atPath: candidate.path) else {
            let directory = candidate.deletingLastPathComponent()
            let base = candidate.deletingPathExtension().lastPathComponent
            let ext = candidate.pathExtension
            var index = 2
            while true {
                let suffix = " \(index)"
                let uniqueBase = sanitizedFileBaseName(base,
                                                       fileExtension: ext,
                                                       uniquenessSuffixByteReservation: suffix.utf8.count)
                let url = directory.appendingPathComponent("\(uniqueBase)\(suffix)").appendingPathExtension(ext)
                if !reservedPaths.contains(url.standardizedFileURL.path),
                   !fileManager.fileExists(atPath: url.path) { return url }
                index += 1
            }
        }
        return candidate
    }


    static func fileURLsReferToSameItem(_ lhs: URL, _ rhs: URL) -> Bool {
        var left = stat()
        var right = stat()
        let leftExists = lhs.withUnsafeFileSystemRepresentation { path in
            path.map { stat($0, &left) == 0 } ?? false
        }
        let rightExists = rhs.withUnsafeFileSystemRepresentation { path in
            path.map { stat($0, &right) == 0 } ?? false
        }
        if leftExists, rightExists {
            return left.st_dev == right.st_dev && left.st_ino == right.st_ino
        }
        let leftPath = lhs.resolvingSymlinksInPath().standardizedFileURL.path
        let rightPath = rhs.resolvingSymlinksInPath().standardizedFileURL.path
        return leftPath == rightPath
    }


    static func temporaryOutputURL(for outputURL: URL,
                                   fileManager: FileManager = .default) throws -> URL {
        let directory = try fileManager.url(for: .itemReplacementDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: outputURL,
                                            create: true)
        let ext = outputURL.pathExtension
        var temporary = directory.appendingPathComponent("Output")
        if !ext.isEmpty { temporary.appendPathExtension(ext) }
        return temporary
    }


    static func discardStagedOutput(_ stagedURL: URL,
                                    fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: stagedURL.deletingLastPathComponent())
    }


    static func installStagedOutput(_ stagedURL: URL, at outputURL: URL,
                                    replacingExisting: Bool = true) throws {
        let result: Int32 = stagedURL.withUnsafeFileSystemRepresentation { stagedPath in
            outputURL.withUnsafeFileSystemRepresentation { outputPath in
                guard let stagedPath, let outputPath else { return Int32(-1) }
                return replacingExisting ? rename(stagedPath, outputPath)
                    : renamex_np(stagedPath, outputPath, UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }


    static func makeVisibleIfNeeded(_ outputURL: URL, fileManager: FileManager = .default) {
        guard shouldForceVisibleOutput(outputURL),
              fileManager.fileExists(atPath: outputURL.path) else { return }
        try? (outputURL as NSURL).setResourceValue(false, forKey: .isHiddenKey)
        var info = stat()
        guard outputURL.withUnsafeFileSystemRepresentation({ path in
            guard let path else { return false }
            return lstat(path, &info) == 0
        }) else { return }
        let flags = UInt32(info.st_flags)
        let visibleFlags = flags & ~UInt32(UF_HIDDEN)
        guard visibleFlags != flags else { return }
        outputURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return }
            _ = chflags(path, visibleFlags)
        }
    }


    static func inputMatchesTool(contentType: UTType?, inputTypes: [UTType]) -> Bool {
        guard let contentType else { return false }
        return inputTypes.contains { contentType.conforms(to: $0) }
    }


    static func outputGrew(originalBytes: Int64, outputBytes: Int64) -> Bool {
        originalBytes > 0 && outputBytes > originalBytes
    }


    private static func shouldForceVisibleOutput(_ outputURL: URL) -> Bool {
        let name = outputURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !name.hasPrefix(".")
    }


    private static func prefix(_ value: String, maxUTF8Bytes: Int) -> String {
        var result = ""
        var usedBytes = 0
        for character in value {
            let count = String(character).utf8.count
            guard usedBytes + count <= maxUTF8Bytes else { break }
            result.append(character)
            usedBytes += count
        }
        return result
    }


}
