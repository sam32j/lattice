// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum NotchMusicRepeatMode: Equatable {
    case off, all, one

    func next(supportsOne: Bool) -> Self {
        switch self {
        case .off: return .all
        case .all: return supportsOne ? .one : .off
        case .one: return .off
        }
    }

    var symbol: String { self == .one ? "repeat.1" : "repeat" }
    var title: String {
        switch self {
        case .off: return "Repeat Off"
        case .all: return "Repeat All"
        case .one: return "Repeat One"
        }
    }
}

/// Only the installed dictionary's playback vocabulary is accepted. Event codes
/// are data supplied by that dictionary, never inferred from an application's name.
struct NotchMusicAutomationCapabilities: Equatable {
    struct Event: Equatable { let eventClass: UInt32; let eventID: UInt32 }
    struct Position: Equatable { let code: UInt32; let integer: Bool }
    /// Only the installed player's dictionary decides which repeat modes exist.
    struct Repeat: Equatable {
        enum Values: Equatable {
            case boolean
            case enumerated(off: UInt32, all: UInt32, one: UInt32)
        }
        let property: UInt32
        let values: Values
        var supportsRepeatOne: Bool {
            if case .enumerated = values { return true }
            return false
        }
    }
    var repeating: Repeat?
    var commands: [String: Event] = [:]
    var position: Position?
    /// The player's own shuffle switch, a writable Boolean of the application.
    var shuffle: UInt32?
    /// Some players' read-only answer to whether the songs playing can be
    /// shuffled at all. Players that do not declare it always can.
    var shuffleAllowed: UInt32?

    var canToggle: Bool { commands["playpause"] != nil || (commands["play"] != nil && commands["pause"] != nil) }

    /// Starts playback rather than toggling it, unless the dictionary only
    /// declares the toggle.
    var playCommand: Event? { commands["play"] ?? commands["playpause"] }

    func event(for command: NotchPlaybackCommand, isPlaying: Bool) -> Event? {
        switch command {
        case .toggle: return commands["playpause"] ?? commands[isPlaying ? "pause" : "play"]
        case .next: return commands["next track"]
        case .previous: return commands["previous track"]
        default: return nil
        }
    }

    static func load(bundleURL: URL) -> Self? {
        guard bundleURL.isFileURL, let bundle = Bundle(url: bundleURL),
              let name = bundle.object(forInfoDictionaryKey: "OSAScriptingDefinition") as? String,
              !name.isEmpty, name.utf8.count <= 255, !name.contains("/"), !name.contains("\\"),
              let resources = bundle.resourceURL,
              let url = bundle.url(forResource: name.hasSuffix(".sdef") ? String(name.dropLast(5)) : name, withExtension: "sdef") else { return nil }
        var relationship = FileManager.URLRelationship.other
        guard (try? FileManager.default.getRelationship(&relationship,
            ofDirectoryAt: resources.resolvingSymlinksInPath(), toItemAt: url.resolvingSymlinksInPath())) != nil,
              relationship == .contains, let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maximumBytes + 1) else { return nil }
        return parse(data)
    }

    static let maximumBytes = 256 * 1024

    static func parse(_ data: Data) -> Self? {
        guard data.count <= maximumBytes else { return nil }
        let reader = MusicDictionaryReader()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = reader
        guard parser.parse(), reader.isDictionary else { return nil }
        let result = reader.finalizedResult()
        guard !result.commands.isEmpty || result.position != nil else { return nil }
        return result
    }
}

private final class MusicDictionaryReader: NSObject, XMLParserDelegate {
    var result = NotchMusicAutomationCapabilities()
    var isDictionary = false
    private var path: [String] = []
    private var elements = 0
    private var applicationDepth: Int?
    private var command: (name: String, event: NotchMusicAutomationCapabilities.Event, valid: Bool)?
    private var seenCommands = Set<String>()
    private var seenPosition = false
    private var seenShuffle = false
    private var seenShuffleAllowed = false
    private var repeatProperty: (property: UInt32, type: String)?
    private var seenRepeat = false
    private var enumeration: (name: String, code: String, modes: [String: UInt32])?
    private var enumerations: [String: [String: UInt32]] = [:]
    private let names: Set<String> = ["playpause", "play", "pause", "next track", "previous track"]
    /// Players call it "shuffling" or "shuffle enabled". A read-only
    /// "shuffling enabled" says whether shuffle is offered at all.
    private let shuffleNames: Set<String> = ["shuffling", "shuffle enabled"]

    private func code(_ value: String?) -> UInt32? {
        guard let value, value.utf8.count == 4,
              value.utf8.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
        return value.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        elements += 1
        path.append(element)
        guard path.count <= 24, elements <= 4096, attributes.count <= 32 else { parser.abortParsing(); return }
        if path.count == 1 { isDictionary = element == "dictionary" }
        if path.count == 3, path.prefix(2).elementsEqual(["dictionary", "suite"]),
           (element == "class" && attributes["name"] == "application")
            || (element == "class-extension" && attributes["extends"] == "application") {
            applicationDepth = path.count
        }
        if element == "enumeration", path == ["dictionary", "suite", "enumeration"],
           let name = attributes["name"], let type = attributes["code"] {
            enumeration = (name, type, [:])
        }
        if element == "enumerator", path == ["dictionary", "suite", "enumeration", "enumerator"],
           let name = attributes["name"], ["off", "one", "all"].contains(name),
           let value = code(attributes["code"]) {
            enumeration?.modes[name] = value
        }
        if element == "command", path == ["dictionary", "suite", "command"],
           let name = attributes["name"], names.contains(name) {
            guard let raw = attributes["code"], raw.utf8.count == 8,
                  let eventClass = code(String(raw.prefix(4))), let eventID = code(String(raw.suffix(4))) else {
                seenCommands.insert(name); result.commands[name] = nil; return
            }
            command = (name, .init(eventClass: eventClass, eventID: eventID), true)
        }
        if command != nil, element == "direct-parameter" || element == "parameter",
           attributes["optional"] != "yes" { command?.valid = false }
        if element == "property", attributes["name"] == "player position",
           let depth = applicationDepth, path.count == depth + 1 {
            defer { seenPosition = true }
            guard !seenPosition, attributes["access"] == nil || ["w", "rw"].contains(attributes["access"] ?? ""),
                  let property = code(attributes["code"]), let type = attributes["type"],
                  type == "real" || type == "integer" else { result.position = nil; return }
            result.position = .init(code: property, integer: type == "integer")
        }
        if element == "property", let name = attributes["name"], shuffleNames.contains(name),
           let depth = applicationDepth, path.count == depth + 1 {
            defer { seenShuffle = true }
            guard !seenShuffle, attributes["access"] == nil || attributes["access"] == "rw",
                  let property = code(attributes["code"]), attributes["type"] == "boolean" else { result.shuffle = nil; return }
            result.shuffle = property
        }
        if element == "property", attributes["name"] == "shuffling enabled",
           let depth = applicationDepth, path.count == depth + 1 {
            defer { seenShuffleAllowed = true }
            guard !seenShuffleAllowed, let property = code(attributes["code"]),
                  attributes["type"] == "boolean" else { result.shuffleAllowed = nil; return }
            result.shuffleAllowed = property
        }
        // Music exposes song repeat as a three-value enumeration; Spotify only
        // exposes a Boolean repeating switch. Never invent an unsupported mode.
        if element == "property", let name = attributes["name"],
           ["song repeat", "repeating"].contains(name),
           let depth = applicationDepth, path.count == depth + 1 {
            defer { seenRepeat = true }
            guard !seenRepeat,
                  attributes["access"] == nil || ["w", "rw"].contains(attributes["access"] ?? ""),
                  let property = code(attributes["code"]), let type = attributes["type"] else {
                repeatProperty = nil
                return
            }
            // Only the exact player property declared in its dictionary.
            if name == "repeating", type != "boolean" { return }
            if name == "song repeat", type == "boolean" { return }
            repeatProperty = (property, type)
        }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        if element == "enumeration", let enumeration {
            // SDEF refers to enumerations by name or by their four-character type.
            if enumerations[enumeration.name] == nil { enumerations[enumeration.name] = enumeration.modes }
            if enumerations[enumeration.code] == nil { enumerations[enumeration.code] = enumeration.modes }
            self.enumeration = nil
        }
        if element == "command", let command {
            if !seenCommands.insert(command.name).inserted { result.commands[command.name] = nil }
            else if command.valid { result.commands[command.name] = command.event }
            self.command = nil
        }
        if applicationDepth == path.count { applicationDepth = nil }
        path.removeLast()
    }

    func finalizedResult() -> NotchMusicAutomationCapabilities {
        guard let repeatProperty else { return result }
        if repeatProperty.type == "boolean" {
            result.repeating = .init(property: repeatProperty.property, values: .boolean)
        } else if let modes = enumerations[repeatProperty.type],
                  let off = modes["off"], let all = modes["all"], let one = modes["one"] {
            result.repeating = .init(property: repeatProperty.property,
                                     values: .enumerated(off: off, all: all, one: one))
        }
        return result
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { parser.abortParsing() }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { parser.abortParsing() }
}
