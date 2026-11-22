// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import UniformTypeIdentifiers

enum URLCleaning {
    /// One parameter the rules took out, and which site's token did it.
    struct Removal: Equatable {
        /// As the link spelled it, decoded.
        let name: String
        let siteID: String
        /// The token that matched, which for a wildcard is not the name.
        let token: String
    }

    /// A cleaned link, the names taken out of it and the names left in, so
    /// every surface that cleans can say what it removed and why.
    struct Result: Equatable {
        let url: String
        /// One per name, in the order the link first carried each.
        let removals: [Removal]
        /// Names left in the link, one per name, in order.
        let kept: [String]

        var removed: [String] { removals.map(\.name) }
    }

    /// What a surface says after cleaning. The choice lives here so the
    /// Settings page, the menu panel and the Command Bar action cannot drift
    /// apart, and so it can be pinned without a view.
    enum Outcome: Equatable {
        case notAURL
        case unchanged
        case rewritten
        case removed([String])
    }

    static func outcome(for result: Result?, input: String) -> Outcome {
        guard let result else { return .notAURL }
        guard result.removed.isEmpty else { return .removed(result.removed) }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.url == trimmed ? .unchanged : .rewritten
    }

    /// The one cleaning function: the clipboard rewrite, the Settings test
    /// card, the menu panel and the Command Bar all call it.
    ///
    /// Each parameter goes when the link's site is on and blocks it, or else
    /// when All sites is on and blocks it, and stays otherwise. The query is
    /// spliced out of the original text rather than rebuilt, so the encoding
    /// of everything kept, the order of what stays and the fragment come back
    /// exactly as they went in.
    static func clean(_ text: String, rules: Rules = .builtIn) -> Result? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = components.host,
              components.url != nil else {
            return nil
        }

        // URLComponents validates the link and supplies its host, but can
        // re-encode existing escapes when a query also contains literal Unicode.
        // Slice the original text by scalars so combining marks cannot hide
        // a query delimiter inside a Character.
        let scalars = trimmed.unicodeScalars
        let fragmentStart = scalars.firstIndex(of: "#") ?? scalars.endIndex
        guard let queryStart = scalars[..<fragmentStart].firstIndex(of: "?") else {
            return Result(url: trimmed, removals: [], kept: [])
        }
        let query = scalars[scalars.index(after: queryStart)..<fragmentStart]
        let site = rules.site(forHost: host).flatMap { $0.isOn ? $0 : nil }
        let global = rules.global.isOn ? rules.global : nil
        var removals: [Removal] = []
        var kept: [String] = []
        // Duplicate names are judged one pair at a time; the lists name
        // each only once.
        let keptPairs = query.split(separator: "&", omittingEmptySubsequences: false)
            .filter { pair in
                let name = Self.decodedName(ofRawPair: pair)
                let parameter = name.lowercased()
                let removal = site.flatMap { site in
                    site.blockingToken(for: parameter).map { Removal(name: name, siteID: site.id, token: $0.name) }
                } ?? global.flatMap { global in
                    global.blockingToken(for: parameter).map { Removal(name: name, siteID: global.id, token: $0.name) }
                }
                guard let removal else {
                    if !name.isEmpty, !kept.contains(where: { $0.lowercased() == parameter }) { kept.append(name) }
                    return true
                }
                if !removals.contains(where: { $0.name.lowercased() == parameter }) { removals.append(removal) }
                return false
            }
        guard !removals.isEmpty else {
            return Result(url: trimmed, removals: [], kept: kept)
        }

        let survivingQuery = keptPairs.map { String($0) }.joined(separator: "&")
        let url = String(scalars[..<queryStart])
            + (keptPairs.isEmpty ? "" : "?" + survivingQuery)
            + String(scalars[fragmentStart...])
        return Result(url: url, removals: removals, kept: kept)
    }

    /// The name half of one percent-encoded `name=value` pair, decoded so a
    /// tracker a link spells as `%75tm_source` or `%24deep_link` is still the
    /// name the rules list. A pair carrying no `=` is a bare flag, so the
    /// whole pair is its name and is matched like any other: a lone
    /// `utm_source` goes, which is what the link dropping the pair meant. Only
    /// an escape that will not decode at all falls back to the raw text, and
    /// even that is matched as written — `utm_%ff` still answers to the
    /// `utm_` prefix.
    private static func decodedName(ofRawPair pair: String.UnicodeScalarView.SubSequence) -> String {
        let raw = String(pair.prefix { $0 != "=" })
        guard raw.contains("%") else { return raw }
        return raw.removingPercentEncoding ?? raw
    }

    // MARK: - Automatic rewrite

    /// Whether the clipboard can be rewritten with a cleaned link without
    /// losing anything the user copied. The rewrite keeps the text, the URL
    /// and a supported link preview. Other types must be text, a link, or an
    /// app's private note about the copy. Refuse a pasteboard that also carries
    /// content of its own: a picture, a file or a
    /// promise to deliver one, a document. A link next to such content is only
    /// its textual fallback (a browser's "Copy Image" also carries the image
    /// URL as text). A copy an app marked concealed or transient is not an
    /// ordinary copy either, and is left alone.
    static func canRewritePasteboard(types: [String]) -> Bool {
        guard !types.isEmpty else { return false }
        return types.allSatisfy(typeSurvivesRewrite)
    }

    private static let plainPasteboardTypes: Set<String> = [
        "public.utf8-plain-text", "public.url", "public.url-name",
        "NSStringPboardType", "NSURLPboardType",
    ]

    /// Marks from the nspasteboard.org convention: concealed is a password
    /// manager handing over a secret, transient is content about to be put
    /// back by whoever placed it.
    private static let untouchablePasteboardTypes: Set<String> = [
        "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
    ]

    /// A file being copied or promised, under the names that are not types
    /// the system knows and would otherwise pass as private notes.
    private static let filePasteboardTypes: Set<String> = [
        "NSFilenamesPboardType",
        "com.apple.NSFilePromiseItemMetaData",
        "Apple files promise pasteboard type",
    ]

    private static func typeSurvivesRewrite(_ rawValue: String) -> Bool {
        if plainPasteboardTypes.contains(rawValue) { return true }
        // Safari's preview is declared data, not text or a URL. Its navigation
        // addresses are rewritten separately before the copy is replaced.
        if rawValue == "com.apple.linkpresentation.metadata" { return true }
        if untouchablePasteboardTypes.contains(rawValue) || filePasteboardTypes.contains(rawValue) {
            return false
        }
        // Unknown to the system, or a dynamic stand-in for a legacy name: an
        // app's private note about the copy, such as a browser's source page
        // or a messaging app's reference to the message. The text does not
        // depend on it, and real content always comes with a type of its own
        // next to it.
        guard let type = UTType(rawValue), type.isDeclared else { return true }
        if type.conforms(to: .fileURL) { return false }
        // Formatted text of the same link: dropped by the rewrite, and
        // nothing is lost that the cleaned link does not say better. An RTFD
        // with an attachment would put an attachment mark in the plain text,
        // which is then no longer a link to clean.
        return type.conforms(to: .text) || type.conforms(to: .url)
            || type.conforms(to: .rtfd) || type.conforms(to: .flatRTFD)
    }
}
