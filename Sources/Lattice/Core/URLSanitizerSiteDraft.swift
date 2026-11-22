// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The Site sheet's working copy. Every edit lands here; only `finalized`
/// hands back a site to store, so Cancel discards by dropping the draft.
struct URLSanitizerSiteDraft: Equatable {
    enum Mode: Equatable {
        case add, edit, global
    }

    enum DomainProblem: Equatable {
        case notADomain(String)
        case claimed(domain: String, siteName: String)
        case missing
    }

    let mode: Mode
    var site: URLCleaning.Site
    var domainInput = ""
    var tokenInput = ""
    var domainProblem: DomainProblem?

    /// A new site with nothing in it yet.
    init(adding id: String = "custom-" + UUID().uuidString) {
        mode = .add
        site = URLCleaning.Site(id: id, name: "", domains: [], tokens: [])
    }

    init(editing site: URLCleaning.Site) {
        mode = site.isGlobal ? .global : .edit
        self.site = site
    }

    var canDelete: Bool { mode == .edit && !site.isBuiltIn }

    /// The primary button waits for a domain, committed or still being typed.
    var canSave: Bool {
        mode == .global || !site.domains.isEmpty
            || !domainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The Name field's placeholder, which is also the name an empty field saves.
    var namePlaceholder: String { site.domains.first ?? "YouTube" }

    /// The tile while adding: the name's monogram, else the first domain's,
    /// else nothing (the sheet shows a plus).
    var previewMonogram: String {
        let fromName = URLCleaning.Site.monogram(for: site.name)
        if !fromName.isEmpty { return fromName }
        let firstDomain = site.domains.first ?? URLCleaning.domain(from: domainInput) ?? ""
        return URLCleaning.Site.monogram(for: firstDomain.split(separator: ".").first.map(String.init) ?? "")
    }

    // MARK: Domains

    /// Commits whatever the domain field holds, split on commas and spaces.
    /// Valid domains become tokens; the first one that is not a domain, or
    /// that another site already lists, stays in the field with its problem.
    /// Answers whether the field is now empty.
    @discardableResult
    mutating func commitDomainInput(rules: URLCleaning.Rules, globalName: String) -> Bool {
        let parts = domainInput.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
        domainProblem = nil
        for (index, part) in parts.enumerated() {
            guard let domain = URLCleaning.domain(from: part) else {
                domainProblem = .notADomain(part)
                domainInput = parts[index...].joined(separator: " ")
                return false
            }
            if let owner = rules.owner(of: domain, excludingID: site.id) {
                domainProblem = .claimed(domain: domain, siteName: owner.isGlobal ? globalName : owner.name)
                domainInput = parts[index...].joined(separator: " ")
                return false
            }
            if !site.domains.contains(domain) { site.domains.append(domain) }
        }
        domainInput = ""
        return true
    }

    /// Backspace in an empty domain field.
    mutating func removeLastDomain() {
        guard domainInput.isEmpty, !site.domains.isEmpty else { return }
        site.domains.removeLast()
        domainProblem = nil
    }

    mutating func removeDomain(_ domain: String) {
        site.domains.removeAll { $0 == domain }
        domainProblem = nil
    }

    // MARK: Tokens

    /// Adds every valid token in the field, split on commas and whitespace,
    /// ignoring ones the site already has. Text that is not a token stays.
    mutating func commitTokenInput() {
        let parts = tokenInput.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
        var rejected: [String] = []
        for part in parts {
            guard let name = URLCleaning.tokenName(from: part) else {
                rejected.append(part)
                continue
            }
            addToken(name)
        }
        tokenInput = rejected.joined(separator: " ")
    }

    mutating func addToken(_ name: String) {
        guard !site.tokens.contains(where: { $0.name == name }) else { return }
        let builtIn = builtInTokenNames.contains(name)
        site.tokens.append(URLCleaning.Token(name: name, isBlocked: true, isCustom: !builtIn))
    }

    mutating func toggleToken(_ name: String) {
        guard let index = site.tokens.firstIndex(where: { $0.name == name }) else { return }
        site.tokens[index].isBlocked.toggle()
    }

    /// Only tokens the user added can go.
    mutating func deleteToken(_ name: String) {
        site.tokens.removeAll { $0.name == name && $0.isCustom }
    }

    mutating func blockAll() {
        for index in site.tokens.indices { site.tokens[index].isBlocked = true }
    }

    // MARK: Save

    /// Commits anything still typed and answers the site to store, or nil
    /// with `domainProblem` saying why not.
    mutating func finalized(rules: URLCleaning.Rules, globalName: String) -> URLCleaning.Site? {
        commitTokenInput()
        guard mode != .global else { return site }
        guard commitDomainInput(rules: rules, globalName: globalName) else { return nil }
        guard !site.domains.isEmpty else {
            domainProblem = .missing
            return nil
        }
        let name = site.name.trimmingCharacters(in: .whitespacesAndNewlines)
        site.name = name.isEmpty ? site.domains[0] : name
        return site
    }

    private var builtInTokenNames: Set<String> {
        if site.isGlobal { return Set(URLCleaning.builtInGlobalSite.tokens.map(\.name)) }
        let template = URLCleaning.builtInSites.first { $0.id == site.id }
        return Set(template?.tokens.map(\.name) ?? [])
    }
}
