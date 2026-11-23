// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Adds a site, edits one, or edits All sites' tokens. Works on a draft:
/// Save applies it, Cancel and Esc drop it.
struct URLSanitizerSiteSheet: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft: URLSanitizerSiteDraft
    let rules: URLCleaning.Rules
    /// Tokens of this site that removed something from the test link.
    let highlightedTokens: Set<String>
    let onSave: (URLCleaning.Site) -> Void
    let onDelete: (String) -> Void
    @FocusState private var focus: Field?
    @State private var tokensHeight: CGFloat = 0

    private enum Field: Hashable { case name, domains, tokens }

    init(draft: URLSanitizerSiteDraft, rules: URLCleaning.Rules, highlightedTokens: Set<String>,
         onSave: @escaping (URLCleaning.Site) -> Void, onDelete: @escaping (String) -> Void) {
        _draft = State(initialValue: draft)
        self.rules = rules
        self.highlightedTokens = highlightedTokens
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var strings: URLSanitizerStrings { FeatureStrings.urlSanitizer(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if draft.mode != .global {
                nameField
                domainsField
            }
            tokensSection
            footer
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            guard draft.mode != .global else { return }
            DispatchQueue.main.async { focus = .name }
        }
        .onChange(of: focus) { old, _ in
            // Leaving a field commits what it holds, as Return would.
            if old == .domains, !draft.domainInput.isEmpty {
                draft.commitDomainInput(rules: rules, globalName: strings.allSites)
            }
            if old == .tokens { draft.commitTokenInput() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            URLSanitizerSiteTile(site: draft.mode == .add ? nil : draft.site,
                                 monogram: draft.mode == .add ? draft.previewMonogram : nil, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var title: String {
        switch draft.mode {
        case .add: return strings.addSiteTitle
        case .edit: return draft.site.name
        case .global: return strings.allSites
        }
    }

    private var subtitle: String {
        switch draft.mode {
        case .add: return strings.addSiteSubtitle
        case .edit: return draft.site.domains.joined(separator: " · ")
        case .global: return strings.globalSubtitle
        }
    }

    // MARK: Name and domains

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(strings.name)
            TextField(strings.name, text: $draft.site.name, prompt: Text(draft.namePlaceholder))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .focused($focus, equals: .name)
                .accessibilityLabel(strings.name)
        }
    }

    private var domainsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                fieldLabel(strings.domains)
                Spacer()
                Text(strings.subdomainsIncluded)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            FlowLayoutLite(spacing: 5) {
                ForEach(draft.site.domains, id: \.self) { domain in
                    domainChip(domain)
                }
                TextField(strings.domains, text: $draft.domainInput,
                          prompt: Text(draft.site.domains.isEmpty ? "youtube.com, youtu.be"
                                       : strings.domainsPlaceholderMore))
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .disableAutocorrection(true)
                    .frame(width: 170, height: 22)
                    .focused($focus, equals: .domains)
                    .accessibilityLabel(strings.domains)
                    .onChange(of: draft.domainInput) { _, text in
                        if text.contains(where: { $0 == "," || $0.isWhitespace }) {
                            draft.commitDomainInput(rules: rules, globalName: strings.allSites)
                        } else if draft.domainProblem != nil, text.isEmpty {
                            draft.domainProblem = nil
                        }
                    }
                    .onSubmit {
                        if draft.domainInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            save()
                        } else {
                            draft.commitDomainInput(rules: rules, globalName: strings.allSites)
                        }
                    }
                    .onKeyPress(.delete) {
                        guard draft.domainInput.isEmpty, !draft.site.domains.isEmpty else { return .ignored }
                        draft.removeLastDomain()
                        return .handled
                    }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(draft.domainProblem != nil ? Color.red.opacity(0.8)
                                  : focus == .domains ? Color.accentColor.opacity(0.6)
                                  : Color.primary.opacity(0.15))
            }
            .contentShape(Rectangle())
            .onTapGesture { focus = .domains }
            if let problem = draft.domainProblem {
                Text(message(for: problem))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func domainChip(_ domain: String) -> some View {
        HStack(spacing: 4) {
            Text(domain)
                .font(.callout)
                .lineLimit(1)
            Button {
                draft.removeDomain(domain)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: strings.removeDomain, domain))
        }
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func message(for problem: URLSanitizerSiteDraft.DomainProblem) -> String {
        switch problem {
        case .notADomain(let input): return String(format: strings.notADomain, input)
        case .claimed(let domain, let siteName): return String(format: strings.domainClaimed, domain, siteName)
        case .missing: return strings.addOneDomain
        }
    }

    // MARK: Tokens

    private var tokensSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                fieldLabel(strings.tokens)
                Spacer()
                if !draft.site.tokens.isEmpty {
                    tokenKey(strings.blocked, count: draft.site.blockedCount, blocked: true)
                    tokenKey(strings.allowed, count: draft.site.allowedCount, blocked: false)
                    if draft.site.allowedCount > 0 {
                        Button(strings.blockAll) { draft.blockAll() }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }
            }
            ScrollView {
                FlowLayoutLite(spacing: 6) {
                    ForEach(draft.site.tokens) { token in
                        URLSanitizerTokenChip(token: token,
                                              isHighlighted: token.isBlocked && highlightedTokens.contains(token.name),
                                              toggle: { draft.toggleToken(token.name) },
                                              delete: { draft.deleteToken(token.name) })
                    }
                    tokenInput
                }
                .padding(8)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tokensHeight = $0 }
            }
            // The sheet never grows taller than the window: past a few rows
            // the chips scroll.
            .frame(height: min(max(tokensHeight, 40), 220))
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(draft.rejectedToken != nil ? Color.red.opacity(0.8) : Color.primary.opacity(0.1))
            }
            if let rejected = draft.rejectedToken {
                Text(String(format: strings.notAToken, rejected))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tokenKey(_ label: String, count: Int, blocked: Bool) -> some View {
        HStack(spacing: 4) {
            URLSanitizerTokenSwatch(isBlocked: blocked)
            Text("\(label) \(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private var tokenInput: some View {
        TextField(strings.addToken, text: $draft.tokenInput, prompt: Text(strings.addToken))
            .textFieldStyle(.plain)
            .labelsHidden()
            .font(.system(size: 11, design: .monospaced))
            .disableAutocorrection(true)
            .focused($focus, equals: .tokens)
            .frame(width: 110)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
            .accessibilityLabel(strings.addToken)
            .onChange(of: draft.tokenInput) { _, text in
                if text.contains(where: { $0 == "," || $0.isWhitespace }) {
                    draft.commitTokenInput()
                } else if text.isEmpty {
                    draft.rejectedToken = nil
                }
            }
            .onSubmit { draft.commitTokenInput() }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if draft.canDelete {
                Button(strings.deleteSite, role: .destructive) {
                    onDelete(draft.site.id)
                    dismiss()
                }
                .foregroundStyle(.red)
            }
            Spacer()
            Button(strings.cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(draft.mode == .add ? strings.addSite : strings.save) { save() }
                .keyboardShortcut(isTypingIntoChips ? nil : .defaultAction)
                .disabled(!draft.canSave)
        }
    }

    /// Return commits a chip while one is being typed, and only saves the
    /// sheet from an empty chip field.
    private var isTypingIntoChips: Bool {
        (focus == .domains && !draft.domainInput.isEmpty) || (focus == .tokens && !draft.tokenInput.isEmpty)
    }

    private func save() {
        guard draft.canSave, let site = draft.finalized(rules: rules, globalName: strings.allSites) else {
            if draft.rejectedToken != nil {
                focus = .tokens
            } else if draft.domainProblem != nil {
                focus = .domains
            }
            return
        }
        onSave(site)
        dismiss()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.medium))
    }
}

// MARK: - Token chip

/// Blocked tokens are filled with a solid edge, allowed ones are hollow with
/// a dashed edge, so the two differ in shape and not only in color.
struct URLSanitizerTokenChip: View {
    @ObservedObject private var l10n = L10n.shared
    let token: URLCleaning.Token
    let isHighlighted: Bool
    let toggle: () -> Void
    let delete: () -> Void
    @State private var hovered = false

    var body: some View {
        let strings = FeatureStrings.urlSanitizer(l10n.language)
        HStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 4) {
                    Text(token.prefix)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                    if token.isWildcard {
                        Text(strings.any)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                            .help(String(format: strings.wildcardHelp, token.prefix))
                    }
                }
                .padding(.horizontal, 7)
                .frame(height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isHighlighted ? strings.highlightedHelp : token.isBlocked ? strings.blockedHelp : strings.allowedHelp)
            .accessibilityLabel(String(format: token.isBlocked ? strings.tokenBlocked : strings.tokenAllowed,
                                       token.name))
            .accessibilityAddTraits(token.isBlocked ? [.isToggle, .isSelected] : .isToggle)
            if token.isCustom {
                Rectangle()
                    .fill(edgeColor.opacity(0.5))
                    .frame(width: 1, height: 12)
                Button(action: delete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(hovered ? 1 : 0.45)
                .help(String(format: strings.deleteToken, token.name))
                .accessibilityLabel(String(format: strings.deleteToken, token.name))
            }
        }
        .foregroundStyle(token.isBlocked ? (isHighlighted ? Color.red : Color.primary) : Color.secondary)
        .background(fillColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(edgeColor, style: StrokeStyle(lineWidth: 1, dash: token.isBlocked ? [] : [3, 2]))
        }
        .onHover { hovered = $0 }
    }

    private var fillColor: Color {
        guard token.isBlocked else { return .clear }
        return isHighlighted ? Color.red.opacity(0.14) : Color.accentColor.opacity(0.14)
    }

    private var edgeColor: Color {
        guard token.isBlocked else { return Color.secondary.opacity(0.6) }
        return isHighlighted ? Color.red.opacity(0.6) : Color.accentColor.opacity(0.45)
    }
}

/// The key's sample of each token style.
struct URLSanitizerTokenSwatch: View {
    let isBlocked: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(isBlocked ? Color.accentColor.opacity(0.14) : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(isBlocked ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.6),
                                  style: StrokeStyle(lineWidth: 1, dash: isBlocked ? [] : [2, 1.5]))
            }
            .frame(width: 12, height: 10)
            .accessibilityHidden(true)
    }
}
