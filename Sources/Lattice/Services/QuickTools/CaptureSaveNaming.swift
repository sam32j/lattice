// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Common file naming for the screenshot and recorder exporters. Pure Foundation
/// apart from the POSIX exclusive create: no saved counter or cached next name.
enum CaptureSaveNaming {
    enum Media: String { case screenshot, recording }
    static let defaultTemplate = "%year-%mo-%d-%h%mi%s"
    struct Expanded {
        let template: String
        let counter: (range: Range<String.Index>, width: Int)?
        let extraCounters: Int
    }
    struct Name {
        let stem: String
        let ext: String
        let counter: (prefix: String, suffix: String, width: Int)?
    }

    static func counterCount(_ template: String) -> Int {
        let characters = Array(template)
        var index = 0, count = 0
        while index < characters.count {
            if characters[index] == "%", index + 1 < characters.count {
                if characters[index + 1] == "%" { index += 2; continue }
                if characters[index + 1] == "#" {
                    count += 1
                    index += 2
                    while index < characters.count && characters[index] == "#" { index += 1 }
                    continue
                }
            }
            index += 1
        }
        return count
    }

    /// Left-to-right token lexer prevents %month becoming %mo + "nth", and
    /// unknown % sequences remain literal, including their percent sign.
    static func expand(_ template: String, date: Date, media: Media,
                       uuid: String = UUID().uuidString.lowercased(),
                       shortID: String = String(UUID().uuidString.prefix(8)).lowercased(),
                       includeCounter: Bool) -> Expanded {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func padded(_ number: Int, _ width: Int) -> String {
            let value = String(number)
            return String(repeating: "0", count: max(0, width - value.count)) + value
        }
        let month = components.month ?? 1
        let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        let replacements: [(String, String)] = [
            ("uuid", uuid), ("year", padded(components.year ?? 0, 4)),
            ("month", monthNames[max(0, min(11, month - 1))]),
            ("media", media.rawValue), ("id", shortID),
            ("mo", padded(month, 2)), ("mi", padded(components.minute ?? 0, 2)),
            ("y", padded((components.year ?? 0) % 100, 2)),
            ("d", padded(components.day ?? 0, 2)), ("h", padded(components.hour ?? 0, 2)),
            ("s", padded(components.second ?? 0, 2)),
        ]
        var result = "", counter: (range: Range<String.Index>, width: Int)?
        var extras = 0
        var index = template.startIndex
        while index < template.endIndex {
            guard template[index] == "%" else {
                result.append(template[index]); index = template.index(after: index); continue
            }
            let next = template.index(after: index)
            if next < template.endIndex && template[next] == "%" {
                result.append("%"); index = template.index(after: next); continue
            }
            if next < template.endIndex && template[next] == "#" {
                var end = template.index(after: next)
                while end < template.endIndex && template[end] == "#" { end = template.index(after: end) }
                if includeCounter && counter == nil {
                    let start = result.endIndex
                    result.append("\u{E000}")
                    counter = (start..<result.endIndex, template.distance(from: next, to: end))
                } else if includeCounter {
                    extras += 1
                    // Extra counters stay literal. Preview/save use only the first.
                    result += String(template[index..<end])
                }
                // A counter in a subfolder is ignored rather than creating
                // unstable number-based directory names.
                index = end
                continue
            }
            if let (token, value) = replacements.first(where: { template[next...].hasPrefix($0.0) }) {
                result += value
                index = template.index(next, offsetBy: token.count)
            } else {
                result.append("%"); index = next
            }
        }
        return Expanded(template: result, counter: counter, extraCounters: extras)
    }

    static func cleanComponent(_ value: String, replacingSlash: Bool = true) -> String {
        let source = value.precomposedStringWithCanonicalMapping
        var result = String.UnicodeScalarView()
        for scalar in source.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) { continue }
            if scalar == ":" || (replacingSlash && scalar == "/") {
                result.append("-")
            } else { result.append(scalar) }
        }
        return String(result).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
    }

    static func subfolders(_ template: String, date: Date, media: Media) -> [String] {
        let expanded = expand(template, date: date, media: media, includeCounter: false).template
        return expanded.split(separator: "/", omittingEmptySubsequences: false)
            .map { cleanComponent(String($0)) }
            .filter { !$0.isEmpty && $0 != ".." && $0 != "." && !$0.hasPrefix("~") }
    }

    private static func byteLimited(_ string: String, limit: Int) -> String {
        var result = ""
        for character in string {
            if (result + String(character)).utf8.count > limit { break }
            result.append(character)
        }
        return result
    }

    static func preparedName(template: String, date: Date, media: Media, ext: String,
                             uuid: String = UUID().uuidString.lowercased(),
                             shortID: String = String(UUID().uuidString.prefix(8)).lowercased()) -> Name {
        let source = template.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = expand(source.isEmpty ? defaultTemplate : source,
                           date: date, media: media, uuid: uuid, shortID: shortID, includeCounter: true)
        let extensionName = String(ext.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
        let safeExtension = extensionName.isEmpty ? "png" : extensionName
        let reserved = safeExtension.utf8.count + 1 + 20 // reserved for collisions/IDs
        var stem = cleanComponent(value.template)
        if stem.isEmpty {
            stem = expand(defaultTemplate, date: date, media: media, includeCounter: false).template
        }
        stem = byteLimited(stem, limit: max(1, 255 - reserved))
        if let marker = stem.range(of: "\u{E000}") {
            let prefix = String(stem[..<marker.lowerBound])
            let suffix = String(stem[marker.upperBound...])
            return Name(stem: stem, ext: safeExtension,
                        counter: (prefix: prefix, suffix: suffix, width: value.counter?.width ?? 1))
        }
        return Name(stem: stem, ext: safeExtension, counter: nil)
    }

    private static func key(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    private static func realName(_ name: String) -> String {
        if name.hasPrefix("."), name.hasSuffix(".icloud") {
            return String(name.dropFirst().dropLast(7))
        }
        return name
    }
    private static func takenNumbers(_ names: [String], prefix: String, suffix: String) -> Set<Int> {
        let start = key(prefix), end = key(suffix)
        var taken = Set<Int>()
        for name in names {
            let normalized = key(realName(name))
            guard normalized.hasPrefix(start), normalized.hasSuffix(end),
                  normalized.count >= start.count + end.count else { continue }
            let first = normalized.index(normalized.startIndex, offsetBy: start.count)
            let last = normalized.index(normalized.endIndex, offsetBy: -end.count)
            let digits = String(normalized[first..<last])
            guard !digits.isEmpty, digits.count <= 9,
                  digits.utf8.allSatisfy({ (48...57).contains($0) }),
                  let number = Int(digits), number > 0 else { continue }
            taken.insert(number)
        }
        return taken
    }
    private static func formatted(_ value: Int, width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }

    static func proposedName(_ spec: Name, names: [String], banned: Set<String> = []) -> String {
        let normalizedNames = Set(names.map { key(realName($0)) }).union(banned.map(key))
        if let counter = spec.counter {
            let suffix = counter.suffix + "." + spec.ext
            let used = takenNumbers(names, prefix: counter.prefix, suffix: suffix)
            var number = 1
            while used.contains(number) || normalizedNames.contains(key(counter.prefix + formatted(number, width: counter.width) + suffix)) { number += 1 }
            return byteLimited(counter.prefix + formatted(number, width: counter.width) + counter.suffix,
                               limit: 254 - spec.ext.utf8.count) + "." + spec.ext
        }
        let name = spec.stem + "." + spec.ext
        if !normalizedNames.contains(key(name)) { return name }
        let suffix = "." + spec.ext
        let used = takenNumbers(names, prefix: spec.stem + " ", suffix: suffix)
        var number = 2
        while used.contains(number) || normalizedNames.contains(key(spec.stem + " " + String(number) + suffix)) { number += 1 }
        return byteLimited(spec.stem + " " + String(number), limit: 254 - spec.ext.utf8.count) + suffix
    }

    static func preview(in folder: URL, subfolderTemplate: String, fileNameTemplate: String,
                        date: Date, media: Media, ext: String,
                        uuid: String = UUID().uuidString.lowercased(),
                        shortID: String = String(UUID().uuidString.prefix(8)).lowercased()) -> URL {
        var destination = folder
        for component in subfolders(subfolderTemplate, date: date, media: media) {
            destination.appendPathComponent(component, isDirectory: true)
        }
        let specification = preparedName(template: fileNameTemplate, date: date, media: media,
                                         ext: ext, uuid: uuid, shortID: shortID)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: destination.path)) ?? []
        return destination.appendingPathComponent(proposedName(specification, names: names))
    }

    enum SaveError: Error { case noAccess, fileClaimFailed, writeFailed }

    static func templates(defaults: UserDefaults = .standard) -> (subfolder: String, name: String) {
        (defaults.string(forKey: DefaultsKey.captureSaveSubfolderTemplate) ?? "",
         defaults.string(forKey: DefaultsKey.captureSaveFileNameTemplate) ?? defaultTemplate)
    }

    static func proposedDestination(in folder: URL, date: Date, media: Media, ext: String,
                                    defaults: UserDefaults = .standard) -> URL {
        let preferences = templates(defaults: defaults)
        return preview(in: folder, subfolderTemplate: preferences.subfolder,
                       fileNameTemplate: preferences.name, date: date, media: media, ext: ext)
    }

    static func saveData(_ data: Data, in folder: URL, date: Date, media: Media,
                         ext: String, defaults: UserDefaults = .standard) throws -> URL {
        let preferences = templates(defaults: defaults)
        return try saveData(data, in: folder, subfolderTemplate: preferences.subfolder,
                            fileNameTemplate: preferences.name, date: date, media: media, ext: ext)
    }

    static func copyFile(from source: URL, in folder: URL, date: Date, media: Media,
                         ext: String, defaults: UserDefaults = .standard) throws -> URL {
        let preferences = templates(defaults: defaults)
        return try copyFile(from: source, in: folder, subfolderTemplate: preferences.subfolder,
                            fileNameTemplate: preferences.name, date: date, media: media, ext: ext)
    }

    /// Reserve a unique empty name for the asynchronous video composer. Only
    /// its owner may replace that placeholder; remove it on export failure.
    static func claim(in folder: URL, date: Date, media: Media, ext: String,
                      defaults: UserDefaults = .standard) throws -> URL {
        let preferences = templates(defaults: defaults)
        return try save(in: folder, subfolderTemplate: preferences.subfolder,
                        fileNameTemplate: preferences.name, date: date, media: media, ext: ext) { _ in }
    }

    /// Exclusive creation is the final arbiter even if another process races
    /// our single directory listing. A failed write always removes its claim.
    static func save(in folder: URL, subfolderTemplate: String, fileNameTemplate: String,
                     date: Date, media: Media, ext: String,
                     write: (FileHandle) throws -> Void) throws -> URL {
        var destination = folder
        for component in subfolders(subfolderTemplate, date: date, media: media) {
            destination.appendPathComponent(component, isDirectory: true)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        let specification = preparedName(template: fileNameTemplate, date: date, media: media, ext: ext)
        var blocked = Set<String>()
        for attempt in 0..<52 {
            let next = attempt >= 50
                ? specification.stem.replacingOccurrences(of: "\u{E000}", with: "") + " " + String(UUID().uuidString.prefix(8)).lowercased() + "." + specification.ext
                : proposedName(specification, names: names, banned: blocked)
            let url = destination.appendingPathComponent(next)
            let fd = url.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, 0o644) }
            guard fd >= 0 else {
                if errno == EEXIST { blocked.insert(next); continue }
                throw SaveError.fileClaimFailed
            }
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            do {
                try write(handle)
                try handle.synchronize()
                try handle.close()
                return url
            } catch {
                try? handle.close()
                try? FileManager.default.removeItem(at: url)
                throw error
            }
        }
        throw SaveError.fileClaimFailed
    }

    static func saveData(_ data: Data, in folder: URL, subfolderTemplate: String,
                         fileNameTemplate: String, date: Date, media: Media, ext: String) throws -> URL {
        try save(in: folder, subfolderTemplate: subfolderTemplate, fileNameTemplate: fileNameTemplate,
                 date: date, media: media, ext: ext) { try $0.write(contentsOf: data) }
    }

    static func copyFile(from source: URL, in folder: URL, subfolderTemplate: String,
                         fileNameTemplate: String, date: Date, media: Media, ext: String) throws -> URL {
        let reader = try FileHandle(forReadingFrom: source)
        defer { try? reader.close() }
        return try save(in: folder, subfolderTemplate: subfolderTemplate,
                        fileNameTemplate: fileNameTemplate, date: date, media: media, ext: ext) { output in
            while let data = try reader.read(upToCount: 256 * 1024), !data.isEmpty {
                try output.write(contentsOf: data)
            }
        }
    }
}
