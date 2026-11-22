// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The URL Sanitizer's rules: one global site that applies to every link, and
/// one site per group of domains with its own tokens. Stored as a whole list,
/// then reconciled with the built-in tables on every read, so tokens and sites
/// a later version adds still reach someone who has already edited theirs.
extension URLCleaning {
    /// One query parameter name the rules know. A name ending in `*` matches
    /// every parameter starting with what comes before it.
    struct Token: Codable, Equatable, Hashable, Identifiable {
        /// Lowercased. Matching ignores case, and duplicates are compared the
        /// same way, so the stored spelling never decides anything.
        var name: String
        /// True removes the parameter from links; false leaves it in.
        var isBlocked: Bool = true
        /// Added by the user, so it can be deleted. Built-in tokens can only
        /// be allowed.
        var isCustom: Bool = false

        var id: String { name }
        var isWildcard: Bool { name.hasSuffix("*") }
        /// The name without its trailing `*`.
        var prefix: String { isWildcard ? String(name.dropLast()) : name }

        /// `parameter` must already be lowercased.
        func matches(_ parameter: String) -> Bool {
            isWildcard ? parameter.hasPrefix(prefix) : parameter == name
        }
    }

    struct Site: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        /// Normalized and unique across every site. Empty for the global site.
        var domains: [String]
        var isGlobal: Bool = false
        var isBuiltIn: Bool = false
        var isOn: Bool = true
        var tokens: [Token]

        var blockedCount: Int { tokens.filter(\.isBlocked).count }
        var allowedCount: Int { tokens.count - blockedCount }

        /// The first blocked token matching `parameter`, which must already
        /// be lowercased.
        func blockingToken(for parameter: String) -> Token? {
            tokens.first { $0.isBlocked && $0.matches(parameter) }
        }

        /// Whether a link to `host`, already normalized with `matchingHost`,
        /// belongs to this site, and through how long a domain.
        func matchLength(forHost host: String) -> Int? {
            domains.filter { host == $0 || host.hasSuffix("." + $0) }.map(\.count).max()
        }

        /// 1 to 2 letters for the site's tile: the first letters of two
        /// words, or the first letter of one. Empty when there is nothing
        /// to take them from.
        static func monogram(for name: String) -> String {
            let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            let letters: [Character]
            if words.count >= 2 {
                letters = [words[0].first, words[1].first].compactMap { $0 }
            } else {
                letters = words.first?.first.map { [$0] } ?? []
            }
            return String(letters).uppercased()
        }
    }

    /// The whole set of sites the cleaner applies, the global one included.
    struct Rules: Equatable {
        /// The global site first, then built-in sites by name, then sites the
        /// user added in the order they were added.
        private(set) var sites: [Site]

        init(sites: [Site]) {
            self.sites = Self.reconciled(sites)
        }

        /// What a fresh install cleans.
        static let builtIn = Rules(sites: [])

        /// Reads the stored list. A missing or unreadable value is the
        /// built-in rules rather than no rules at all.
        init(storedValue: String?) {
            self.init(sites: Self.decodeSites(storedValue) ?? [])
        }

        var storageValue: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(sites) else { return "" }
            return String(decoding: data, as: UTF8.self)
        }

        var global: Site {
            sites.first(where: \.isGlobal) ?? URLCleaning.builtInGlobalSite
        }

        func site(id: String) -> Site? {
            sites.first { $0.id == id }
        }

        /// The site a link to `host` belongs to. Domains are unique, so the
        /// only way two sites can match is one domain nested in another, like
        /// `music.example.com` beside `example.com`; the more specific one wins.
        func site(forHost host: String) -> Site? {
            let normalized = URLCleaning.matchingHost(host)
            return sites.filter { !$0.isGlobal }
                .compactMap { site in site.matchLength(forHost: normalized).map { (site, $0) } }
                .max { $0.1 < $1.1 }?.0
        }

        /// The site that already lists `domain`, other than `excludingID`.
        func owner(of domain: String, excludingID: String?) -> Site? {
            sites.first { $0.id != excludingID && $0.domains.contains(domain) }
        }

        /// Replaces the site with the same id, or appends a new one.
        mutating func upsert(_ site: Site) {
            var updated = sites
            if let index = updated.firstIndex(where: { $0.id == site.id }) {
                updated[index] = site
            } else {
                updated.append(site)
            }
            sites = Self.reconciled(updated)
        }

        /// Built-in sites and the global one cannot be deleted.
        mutating func delete(id: String) {
            sites = Self.reconciled(sites.filter { $0.id != id || $0.isBuiltIn || $0.isGlobal })
        }

        mutating func setSite(id: String, isOn: Bool) {
            guard let index = sites.firstIndex(where: { $0.id == id }) else { return }
            sites[index].isOn = isOn
        }

        private static func decodeSites(_ storedValue: String?) -> [Site]? {
            guard let storedValue, !storedValue.isEmpty else { return nil }
            return try? JSONDecoder().decode([Site].self, from: Data(storedValue.utf8))
        }

        /// Restores what every list must have: exactly one global site, every
        /// built-in site with every built-in token, domains normalized and
        /// unique, tokens unique, and the display order.
        static func reconciled(_ stored: [Site]) -> [Site] {
            var claimed = Set<String>()
            var seenIDs = Set<String>()
            var global: Site?
            var builtIns: [Site] = []
            var custom: [Site] = []
            let templates = Dictionary(uniqueKeysWithValues: URLCleaning.builtInSites.map { ($0.id, $0) })

            for var site in stored {
                guard seenIDs.insert(site.id).inserted else { continue }
                if site.isGlobal || site.id == URLCleaning.globalSiteID {
                    guard global == nil else { continue }
                    var merged = URLCleaning.builtInGlobalSite
                    merged.isOn = site.isOn
                    merged.tokens = URLCleaning.mergedTokens(site.tokens, builtIn: merged.tokens)
                    global = merged
                    continue
                }
                site.domains = site.domains.compactMap(URLCleaning.domain(from:))
                    .filter { claimed.insert($0).inserted }
                if let template = templates[site.id] {
                    site.isBuiltIn = true
                    site.isGlobal = false
                    if site.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        site.name = template.name
                    }
                    site.tokens = URLCleaning.mergedTokens(site.tokens, builtIn: template.tokens)
                    builtIns.append(site)
                } else {
                    guard !site.domains.isEmpty else { continue }
                    site.isBuiltIn = false
                    site.isGlobal = false
                    site.tokens = URLCleaning.mergedTokens(site.tokens, builtIn: [])
                    if site.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        site.name = site.domains[0]
                    }
                    custom.append(site)
                }
            }
            // A built-in site this list has never seen, because it predates
            // the site or never stored one. Domains another site has since
            // claimed stay with that site.
            for template in URLCleaning.builtInSites where !seenIDs.contains(template.id) {
                var site = template
                site.domains = site.domains.filter { claimed.insert($0).inserted }
                guard !site.domains.isEmpty else { continue }
                builtIns.append(site)
            }
            builtIns.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return [global ?? URLCleaning.builtInGlobalSite] + builtIns + custom
        }
    }

    /// Stored tokens first, deduplicated without regard to case, with any
    /// built-in token the stored list lacks appended blocked. A stored name
    /// the built-in list now carries becomes built-in, since it can no
    /// longer be deleted.
    static func mergedTokens(_ stored: [Token], builtIn: [Token]) -> [Token] {
        let builtInNames = Set(builtIn.map(\.name))
        var seen = Set<String>()
        var tokens: [Token] = []
        for var token in stored {
            guard let name = tokenName(from: token.name), seen.insert(name).inserted else { continue }
            token.name = name
            token.isCustom = !builtInNames.contains(name)
            tokens.append(token)
        }
        for token in builtIn where seen.insert(token.name).inserted {
            tokens.append(token)
        }
        return tokens
    }

    // MARK: - Built-in tables

    static let globalSiteID = "all-sites"

    /// Trackers every site uses. The `utm_` family is one wildcard token, so
    /// the list does not show names that cannot be allowed one by one.
    private static let globalTokenNames = [
        "utm_*",
        "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid",
        "mc_cid", "mc_eid", "igshid", "twclid", "ttclid", "li_fat_id",
        "mkt_tok", "_hsenc", "_hsmi", "__twitter_impression",
        "fb_action_ids", "fb_action_types", "fb_source", "mibextid",
    ]

    static var builtInGlobalSite: Site {
        Site(id: globalSiteID, name: "All sites", domains: [], isGlobal: true, isBuiltIn: true,
             tokens: globalTokenNames.map { Token(name: $0) })
    }

    /// Trackers that only one site uses. A global list cannot hold these: `si`
    /// is a share token on YouTube but a real parameter elsewhere, and `t` is a
    /// tracker on X while it is the playback position on YouTube. Matching on
    /// the host is what keeps removing one from breaking the other.
    ///
    /// Reddit's share sheet routes through branch.io, whose deep link fields
    /// start with a literal `$`. Links often carry them percent-encoded as
    /// `%24…`, but only the decoded spelling is listed: the cleaner decodes
    /// the name half of each pair before the rules see it.
    static let builtInSites: [Site] = [
        builtIn("bilibili", "Bilibili", ["bilibili.com"], [
            "spm_id_from", "from_spmid", "from_source", "share_source", "share_from",
            "share_medium", "share_plat", "share_tag", "share_session_id", "msource",
            "refer_from", "seid", "unique_k", "vd_source", "plat_id", "buvid", "bbid",
            "up_id", "is_story_h5", "timestamp", "ts", "visit_id", "session_id",
            "broadcast_type", "is_room_feed",
        ]),
        builtIn("instagram", "Instagram", ["instagram.com"], ["igsh"]),
        builtIn("reddit", "Reddit", ["reddit.com"], [
            "correlation_id", "ref_campaign", "ref_source", "rdt", "share_id",
            "_branch_match_id", "$deep_link", "$3p", "$original_url",
        ]),
        builtIn("spotify", "Spotify", ["spotify.com"], ["si"]),
        builtIn("tiktok", "TikTok", ["tiktok.com"], [
            "u_code", "preview_pb", "_d", "_t", "_r", "timestamp", "user_id",
            "share_app_name", "share_iid",
        ]),
        builtIn("x", "X", ["x.com", "twitter.com"], ["s", "t", "cn", "src", "refsrc", "ref_src", "ref_url"]),
        builtIn("xiaohongshu", "Xiaohongshu", ["xiaohongshu.com"], [
            "xhsshare", "author_share", "xsec_source", "share_from_user_hidden",
            "shareredid", "share_id", "exsource", "app_version", "app_platform",
            "apptime", "appuid",
        ]),
        builtIn("youtube", "YouTube", ["youtube.com", "youtu.be"], ["si", "pp", "feature", "kw"]),
    ]

    private static func builtIn(_ id: String, _ name: String, _ domains: [String], _ tokens: [String]) -> Site {
        Site(id: id, name: name, domains: domains, isBuiltIn: true, tokens: tokens.map { Token(name: $0) })
    }

    // MARK: - Normalization

    /// Prefixes a link's host may carry that do not change which site it is.
    static let ignoredHostPrefixes = ["www.", "m.", "mobile.", "open."]

    /// Lowercased, with one leading `www.`, `m.`, `mobile.` or `open.` taken
    /// off. Only a prefix in front of a whole domain goes: `open.com` is the
    /// site itself, not `com` opened.
    static func matchingHost(_ host: String) -> String {
        let lowered = host.lowercased()
        for prefix in ignoredHostPrefixes where lowered.hasPrefix(prefix) {
            let rest = lowered.dropFirst(prefix.count)
            if rest.contains(".") { return String(rest) }
        }
        return lowered
    }

    /// Accepts what someone is likely to paste into the domain field — a bare
    /// host, a `www.` host or a whole link — and answers with the domain the
    /// rules store, or nil when it is not a domain at all. The same leading
    /// prefixes links lose before matching are taken off here, or a domain
    /// written as `m.example.com` could never match anything.
    static func domain(from text: String) -> String? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = value.range(of: "://") {
            value = String(value[scheme.upperBound...])
        }
        if let end = value.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            value = String(value[..<end])
        }
        // A link's host carries neither a login nor a port, so a domain that
        // kept them would never match the link it was written for.
        if let login = value.lastIndex(of: "@") {
            value = String(value[value.index(after: login)...])
        }
        // Colons inside a bracketed IPv6 host belong to the address.
        let portSearchStart = value.hasPrefix("[")
            ? value.firstIndex(of: "]") ?? value.endIndex
            : value.startIndex
        if let port = value[portSearchStart...].firstIndex(of: ":") {
            value = String(value[..<port])
        }
        if value.hasPrefix("[") {
            let inner = value.dropFirst().dropLast()
            guard value.hasSuffix("]"), !inner.isEmpty,
                  inner.allSatisfy({ $0.isHexDigit || $0 == ":" || $0 == "." }) else { return nil }
            return value
        }
        value = matchingHost(value)
        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({ label in
                  !label.isEmpty && !label.hasPrefix("-") && !label.hasSuffix("-")
                      && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
              }) else {
            return nil
        }
        return value
    }

    /// A token is one query parameter name, or a prefix ending in `*`.
    /// Anything a query cannot carry as one name is refused rather than
    /// stored.
    static func tokenName(from text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let body = value.hasSuffix("*") ? value.dropLast() : Substring(value)
        guard !body.isEmpty,
              body.allSatisfy({ !$0.isWhitespace && !"|,&=*?#".contains($0) }) else {
            return nil
        }
        return value
    }

    /// Every token in pasted text, split on commas and whitespace, valid ones
    /// only, in order and without duplicates.
    static func tokenNames(fromPasted text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .compactMap { tokenName(from: String($0)) }
            .filter { seen.insert($0).inserted }
    }

    // MARK: - Migration

    /// The one-time move from the Clean URL lists to sites. Every per-site
    /// list becomes a site and the global list the global site; checked names
    /// are blocked, unchecked ones allowed, and names the user added custom.
    /// X's and YouTube's two hosts each become one site, and a name unchecked
    /// on either host stays allowed.
    static func migratedSites(globalNames: String?, siteNames: String?, disabledNames: String?) -> [Site] {
        let added = legacyTokens(from: siteNames)
        let disabled = legacyTokens(from: disabledNames)
        let addedGlobal = Set(splitLegacy(globalNames).map { $0.lowercased() })

        func tokens(builtIn: [Token], added: Set<String>, disabled: Set<String>) -> [Token] {
            let builtInNames = Set(builtIn.map(\.name))
            return builtIn.map { Token(name: $0.name, isBlocked: !disabled.contains($0.name)) }
                + added.subtracting(builtInNames).sorted().compactMap { name in
                    tokenName(from: name).map { Token(name: $0, isBlocked: !disabled.contains(name), isCustom: true) }
                }
        }

        var global = builtInGlobalSite
        global.tokens = tokens(builtIn: global.tokens, added: addedGlobal, disabled: disabled[""] ?? [])

        // Old hosts grouped under the domain each now belongs to.
        var hostsByDomain: [String: [String]] = [:]
        var domainOrder: [String] = []
        for host in Set(added.keys).union(disabled.keys) where !host.isEmpty {
            guard let domain = domain(from: host) else { continue }
            if hostsByDomain[domain] == nil { domainOrder.append(domain) }
            hostsByDomain[domain, default: []].append(host)
        }

        var sites = [global]
        var consumed = Set<String>()
        for template in builtInSites {
            let hosts = template.domains.flatMap { hostsByDomain[$0] ?? [] }
            consumed.formUnion(template.domains)
            var site = template
            site.tokens = tokens(builtIn: template.tokens,
                                 added: hosts.reduce(into: Set()) { $0.formUnion(added[$1] ?? []) },
                                 disabled: hosts.reduce(into: Set()) { $0.formUnion(disabled[$1] ?? []) })
            sites.append(site)
        }
        for domain in domainOrder.sorted() where !consumed.contains(domain) {
            let hosts = hostsByDomain[domain] ?? []
            let names = hosts.reduce(into: Set<String>()) { $0.formUnion(added[$1] ?? []) }
            guard !names.isEmpty else { continue }
            let off = hosts.reduce(into: Set<String>()) { $0.formUnion(disabled[$1] ?? []) }
            sites.append(Site(id: "custom-" + domain, name: domain, domains: [domain],
                              tokens: tokens(builtIn: [], added: names, disabled: off)))
        }
        return Rules(sites: sites).sites
    }

    /// `host|name` tokens, as the Clean URL lists stored them.
    private static func legacyTokens(from storedValue: String?) -> [String: Set<String>] {
        var map: [String: Set<String>] = [:]
        for token in splitLegacy(storedValue) {
            let parts = token.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let name = String(parts[1]).lowercased()
            guard !name.isEmpty else { continue }
            map[String(parts[0]).lowercased(), default: []].insert(name)
        }
        return map
    }

    private static func splitLegacy(_ storedValue: String?) -> [String] {
        (storedValue ?? "")
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Search

    /// A site the Sites search kept, and the tokens that made it match when
    /// its name and domains did not.
    struct SearchMatch: Equatable {
        let site: Site
        let matchingTokens: [String]
    }

    /// Case-insensitive substring match on name, domains and token names. An
    /// empty query keeps every site. `globalName` is the global site's name
    /// as the page shows it.
    static func search(_ query: String, in sites: [Site], globalName: String) -> [SearchMatch] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return sites.map { SearchMatch(site: $0, matchingTokens: []) } }
        func contains(_ text: String) -> Bool { text.range(of: needle, options: .caseInsensitive) != nil }
        return sites.compactMap { site in
            let name = site.isGlobal ? globalName : site.name
            if contains(name) || site.domains.contains(where: contains) {
                return SearchMatch(site: site, matchingTokens: [])
            }
            let tokens = site.tokens.map(\.name).filter(contains)
            return tokens.isEmpty ? nil : SearchMatch(site: site, matchingTokens: tokens)
        }
    }
}
