// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The URL Sanitizer page: a header with the main switch and a Settings
/// menu, a card to test a link against the saved rules, the sites those
/// rules are made of, and the links cleaned this session. Anything that
/// needs more room opens in a sheet or a menu, so the page never grows a
/// block in place.
struct URLSanitizerSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var cleaner = URLCleanerService.shared
    @AppStorage(DefaultsKey.urlCleanerEnabled) private var enabled = false
    @AppStorage(DefaultsKey.urlSanitizerAutoRemove) private var autoRemove = true
    @AppStorage(DefaultsKey.urlSanitizerSites) private var storedSites = ""
    @State private var input = ""
    @State private var search = ""
    @State private var sheet: SheetRequest?

    /// Only saved rules: a sheet's unsaved edits never reach the test card.
    private var rules: URLCleaning.Rules {
        URLCleaning.Rules(storedValue: storedSites)
    }

    private var strings: URLSanitizerStrings { FeatureStrings.urlSanitizer(l10n.language) }

    var body: some View {
        let rules = rules
        let result = URLCleaning.clean(input, rules: rules)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                URLSanitizerHeader(enabled: $enabled, autoRemove: $autoRemove)
                URLSanitizerTestCard(input: $input, result: result, rules: rules,
                                     isPaused: !enabled || !autoRemove,
                                     openSite: { open($0, rules: rules) })
                sitesCard(rules: rules, result: result)
                recentCard
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .sheet(item: $sheet) { request in
            URLSanitizerSiteSheet(draft: request.draft, rules: rules,
                                  highlightedTokens: highlightedTokens(for: request.draft.site.id, in: result),
                                  onSave: save, onDelete: delete)
        }
    }

    // MARK: Sites

    private func sitesCard(rules: URLCleaning.Rules, result: URLCleaning.Result?) -> some View {
        let matches = URLCleaning.search(search, in: rules.sites, globalName: strings.allSites)
        let usedSites = Set(result?.removals.map(\.siteID) ?? [])
        return SettingsCard(title: strings.sitesTitle, headerAccessory: {
            HStack(spacing: 8) {
                URLSanitizerSearchField(text: $search, prompt: strings.searchPlaceholder)
                    .frame(width: 180)
                Button {
                    sheet = SheetRequest(draft: URLSanitizerSiteDraft())
                } label: {
                    Label(strings.add, systemImage: "plus")
                }
                .controlSize(.small)
            }
        }) {
            VStack(spacing: 0) {
                if matches.isEmpty {
                    Text(strings.noMatches)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                ForEach(Array(matches.enumerated()), id: \.element.site.id) { index, match in
                    if index > 0 { Divider() }
                    URLSanitizerSiteRow(site: match.site, matchingTokens: match.matchingTokens,
                                        isUsedByTestLink: usedSites.contains(match.site.id),
                                        open: { open(match.site.id, rules: rules) },
                                        setOn: { setSite(match.site.id, isOn: $0) })
                }
            }
        }
    }

    // MARK: Recently cleaned

    private var recentCard: some View {
        SettingsCard(title: strings.recentTitle, headerAccessory: {
            Text(strings.thisSession)
                .font(.caption)
                .foregroundStyle(.secondary)
        }) {
            if cleaner.recent.isEmpty {
                Text(strings.recentEmpty)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                // Relative times keep moving while the page is open.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(spacing: 0) {
                        ForEach(Array(cleaner.recent.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider() }
                            URLSanitizerRecentRow(entry: entry, now: context.date)
                        }
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func open(_ siteID: String, rules: URLCleaning.Rules) {
        guard let site = rules.site(id: siteID) else { return }
        sheet = SheetRequest(draft: URLSanitizerSiteDraft(editing: site))
    }

    private func highlightedTokens(for siteID: String, in result: URLCleaning.Result?) -> Set<String> {
        Set(result?.removals.filter { $0.siteID == siteID }.map(\.token) ?? [])
    }

    private func save(_ site: URLCleaning.Site) {
        var updated = rules
        updated.upsert(site)
        storedSites = updated.storageValue
    }

    private func delete(_ siteID: String) {
        var updated = rules
        updated.delete(id: siteID)
        storedSites = updated.storageValue
    }

    private func setSite(_ siteID: String, isOn: Bool) {
        var updated = rules
        updated.setSite(id: siteID, isOn: isOn)
        storedSites = updated.storageValue
    }

    private struct SheetRequest: Identifiable {
        let id = UUID()
        let draft: URLSanitizerSiteDraft
    }
}

// MARK: - Header

/// Icon, title, the Settings menu and the main switch. The switch shows the
/// state on its own, so there is no status text beside it.
private struct URLSanitizerHeader: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var enabled: Bool
    @Binding var autoRemove: Bool
    @State private var showingMenu = false
    /// A click on the gear while the menu is open first closes it as a click
    /// outside; this keeps that same click from opening it again.
    @State private var menuClosedAt = Date.distantPast

    private var strings: URLSanitizerStrings { FeatureStrings.urlSanitizer(l10n.language) }

    var body: some View {
        HStack(spacing: 10) {
            LatticeSymbol(AppFeature.urlCleaner.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text(l10n.s.urlCleanerName)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Button {
                guard Date().timeIntervalSince(menuClosedAt) > 0.3 else { return }
                showingMenu.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(showingMenu ? Color.primary : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(showingMenu ? Color.primary.opacity(0.1) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(strings.settingsButton)
            .accessibilityLabel(strings.settingsButton)
            .accessibilityAddTraits(showingMenu ? .isSelected : [])
            .popover(isPresented: $showingMenu, arrowEdge: .bottom) {
                URLSanitizerSettingsMenu(autoRemove: $autoRemove)
            }
            .onChange(of: showingMenu) { _, open in
                if !open { menuClosedAt = Date() }
            }
            Toggle(strings.mainToggle, isOn: $enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(strings.mainToggle)
                .help(strings.mainToggle)
                .onChange(of: enabled) { _, enabled in
                    settingsApplyFeatureSwitch(enabled: enabled) {
                        URLCleanerService.shared.syncWithPreferences()
                        FeatureRuntime.shared.finishAvailabilityChange()
                    }
                }
        }
    }
}

/// The gear's menu: one row per option, each a title, a line of help and a
/// switch, clickable anywhere. More options add more rows.
private struct URLSanitizerSettingsMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var autoRemove: Bool

    var body: some View {
        let strings = FeatureStrings.urlSanitizer(l10n.language)
        VStack(alignment: .leading, spacing: 0) {
            URLSanitizerMenuToggleRow(title: strings.autoRemoveTitle, help: strings.autoRemoveHelp,
                                      isOn: $autoRemove)
                .onChange(of: autoRemove) { _, _ in
                    URLCleanerService.shared.syncWithPreferences()
                }
        }
        .padding(6)
        .frame(width: 300)
    }
}

private struct URLSanitizerMenuToggleRow: View {
    let title: String
    let help: String
    @Binding var isOn: Bool
    @State private var hovered = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle(title, isOn: .constant(isOn))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(hovered ? Color.primary.opacity(0.06) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityRepresentation {
            Toggle(title, isOn: $isOn)
                .accessibilityHint(help)
        }
    }
}

// MARK: - Sites

private struct URLSanitizerSiteRow: View {
    @ObservedObject private var l10n = L10n.shared
    let site: URLCleaning.Site
    let matchingTokens: [String]
    let isUsedByTestLink: Bool
    let open: () -> Void
    let setOn: (Bool) -> Void
    @State private var hovered = false

    var body: some View {
        let strings = FeatureStrings.urlSanitizer(l10n.language)
        let name = site.isGlobal ? strings.allSites : site.name
        HStack(spacing: 10) {
            Button(action: open) {
                HStack(spacing: 10) {
                    URLSanitizerSiteTile(site: site, size: 24)
                    Text(name)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Text(secondary(strings))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    if isUsedByTestLink {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .help(strings.usedByTestLink)
                            .accessibilityLabel(strings.usedByTestLink)
                    }
                    Text(count(strings))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 6)
                .frame(height: 34)
                .background(hovered ? Color.primary.opacity(0.05) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
                .opacity(site.isOn ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
            .accessibilityLabel([name, secondary(strings), count(strings)].joined(separator: ", "))
            Toggle(String(format: strings.cleanSite, name), isOn: Binding(get: { site.isOn }, set: setOn))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(String(format: strings.cleanSite, name))
        }
        .padding(.horizontal, -6)
    }

    private func secondary(_ strings: URLSanitizerStrings) -> String {
        if !matchingTokens.isEmpty {
            return String(format: strings.has, matchingTokens.joined(separator: ", "))
        }
        return site.isGlobal ? strings.everyLink : site.domains.joined(separator: ", ")
    }

    private func count(_ strings: URLSanitizerStrings) -> String {
        guard site.isOn else { return strings.off }
        return site.allowedCount > 0 ? "\(site.blockedCount)/\(site.tokens.count)" : "\(site.tokens.count)"
    }
}

/// A globe for All sites, otherwise the name's monogram.
struct URLSanitizerSiteTile: View {
    let site: URLCleaning.Site?
    var monogram: String? = nil
    let size: CGFloat

    var body: some View {
        Group {
            if site?.isGlobal == true {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.5, weight: .semibold))
            } else {
                let letters = monogram ?? site.map { URLCleaning.Site.monogram(for: $0.name) } ?? ""
                if letters.isEmpty {
                    Image(systemName: "plus")
                        .font(.system(size: size * 0.45, weight: .semibold))
                } else {
                    Text(letters)
                        .font(.system(size: size * (letters.count > 1 ? 0.4 : 0.48), weight: .semibold,
                                      design: .rounded))
                }
            }
        }
        .foregroundStyle(Color.accentColor)
        .frame(width: size, height: size)
        .background(Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct URLSanitizerSearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .font(.callout)
                .labelsHidden()
                .disableAutocorrection(true)
                .focused($focused)
                .onExitCommand { text = "" }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.shared.s.urlCleanerClearButton)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(focused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.12))
        }
    }
}

// MARK: - Recently cleaned

private struct URLSanitizerRecentRow: View {
    @ObservedObject private var l10n = L10n.shared
    let entry: URLCleanerService.RecentClean
    let now: Date
    @State private var copied = false

    var body: some View {
        let strings = FeatureStrings.urlSanitizer(l10n.language)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.host)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(meta(strings))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                Text(entry.cleaned)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button(copied ? strings.copied : strings.copyOriginal) {
                URLCleanerService.shared.copy(entry.original)
                copied = true
            }
            .buttonStyle(.link)
            .fixedSize()
        }
        .padding(.vertical, 7)
    }

    private func meta(_ strings: URLSanitizerStrings) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        let time = formatter.localizedString(for: min(entry.date, now), relativeTo: now)
        return strings.trackerCount(entry.trackerCount, l10n.language) + " · " + time
    }
}
