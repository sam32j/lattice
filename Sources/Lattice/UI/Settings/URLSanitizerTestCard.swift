// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Test a link: an Original row to type into, a Cleaned row with the result
/// under the saved rules, and one line naming what went and what stayed.
/// The Cleaned row unrolls once there is a link to clean and folds away when
/// the field empties; the page keys the motion on `isEmpty(_:)`.
struct URLSanitizerTestCard: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var input: String
    let result: URLCleaning.Result?
    let rules: URLCleaning.Rules
    /// Off or not rewriting automatically: tooltips say "would be removed".
    let isPaused: Bool
    let openSite: (String) -> Void
    @State private var copiedURL: String?
    @State private var copyGeneration = 0

    private var strings: URLSanitizerStrings { FeatureStrings.urlSanitizer(l10n.language) }
    private var isEmpty: Bool { Self.isEmpty(input) }

    static func isEmpty(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SettingsCard(title: strings.testTitle) {
            VStack(alignment: .leading, spacing: 10) {
                linkField
                URLSanitizerResultLine(result: isEmpty ? nil : result, rules: rules,
                                       isPaused: isPaused, openSite: openSite)
            }
        }
    }

    // MARK: Field

    /// Both rows share one label column, one text column and one action
    /// column. Each column is as wide as the widest thing either row can put
    /// in it, so the link text starts at the same x and the two buttons are
    /// the same width in every language.
    private var linkField: some View {
        VStack(spacing: 0) {
            row(label: originalLabel, actions: originalActions) {
                TextField(strings.originalPlaceholder, text: $input, prompt: Text(strings.originalPlaceholder))
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .labelsHidden()
                    .disableAutocorrection(true)
                    .accessibilityLabel(strings.original)
            }
            if !isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    row(label: cleanedLabel, actions: cleanedActions) {
                        cleanedText
                    }
                    .background(Color.accentColor.opacity(0.06))
                }
                .transition(.settingsReveal)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        }
    }

    private func row<Text: View, Label: View, Actions: View>(
        label: Label, actions: Actions, @ViewBuilder text: () -> Text) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                originalLabel.hidden()
                cleanedLabel.hidden()
                label
            }
            text()
                .frame(maxWidth: .infinity, alignment: .leading)
            ZStack(alignment: .trailing) {
                originalActions.hidden().accessibilityHidden(true)
                cleanedActions.hidden().accessibilityHidden(true)
                actions
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
    }

    private var originalLabel: some View {
        SwiftUI.Label(strings.original, systemImage: "link")
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
    }

    private var cleanedLabel: some View {
        SwiftUI.Label(strings.cleaned, systemImage: "checkmark")
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder
    private var cleanedText: some View {
        if let result {
            SwiftUI.Text(result.url)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(result.url)
        } else {
            placeholder(strings.invalidLink)
        }
    }

    private func placeholder(_ text: String) -> some View {
        SwiftUI.Text(text)
            .font(.callout)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var originalActions: some View {
        HStack(spacing: 6) {
            Button {
                input = ""
                copiedURL = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(strings.clearLink)
            .accessibilityLabel(strings.clearLink)
            .opacity(input.isEmpty ? 0 : 1)
            .disabled(input.isEmpty)
            .accessibilityHidden(input.isEmpty)
            Button(action: paste) { buttonTitle(strings.paste) }
                .controlSize(.small)
        }
    }

    private var cleanedActions: some View {
        let copied = copiedURL != nil && copiedURL == result?.url
        return HStack(spacing: 6) {
            Color.clear.frame(width: 18, height: 18)
            Button(action: copy) {
                buttonTitle(copied ? strings.copied : strings.copy,
                            symbol: copied ? "checkmark" : nil)
            }
            .buttonStyle(.borderedProminent)
            .tint(copied ? .green : nil)
            .controlSize(.small)
            .disabled(isEmpty || result == nil)
        }
    }

    /// Every title either button can show, stacked, so Paste, Copy and
    /// Copied all take the widest one's width.
    private func buttonTitle(_ title: String, symbol: String? = nil) -> some View {
        ZStack {
            ForEach([strings.paste, strings.copy, strings.copied], id: \.self) { candidate in
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                    SwiftUI.Text(candidate)
                }
                .hidden()
            }
            HStack(spacing: 3) {
                if let symbol { Image(systemName: symbol) }
                SwiftUI.Text(title)
            }
        }
    }

    // MARK: Actions

    /// Through the shared lane: a direct read here would both race the
    /// clipboard services on AppKit's pasteboard cache and hang the button
    /// (and with it the app) on a promised flavour nobody renders any more.
    private func paste() {
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.string(forType: .string) ?? ""
        }, then: { pasted in
            self.input = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        })
    }

    private func copy() {
        guard !isEmpty, let result else { return }
        URLCleanerService.shared.copy(result.url)
        URLCleanerService.shared.record(original: input.trimmingCharacters(in: .whitespacesAndNewlines),
                                        result: result)
        copiedURL = result.url
        copyGeneration &+= 1
        let generation = copyGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copyGeneration == generation { copiedURL = nil }
        }
    }
}

// MARK: - Result line

/// One line: the trackers removed on the left, the parameters left in on the
/// right. Each group shows as many tokens as its rendered width allows and
/// folds the rest into `+N`. The right group gets at most a third of the
/// line so it can never starve the left.
struct URLSanitizerResultLine: View {
    @ObservedObject private var l10n = L10n.shared
    let result: URLCleaning.Result?
    let rules: URLCleaning.Rules
    let isPaused: Bool
    let openSite: (String) -> Void

    static let gap: CGFloat = 6

    private var strings: URLSanitizerStrings { FeatureStrings.urlSanitizer(l10n.language) }

    var body: some View {
        URLSanitizerResultLineLayout(groupGap: 16) {
            removedGroup
            if let kept = result?.kept, !kept.isEmpty {
                fittedGroup(label: strings.other, count: kept.count, hidden: { Array(kept[$0...]) }) { shown in
                    ForEach(kept.prefix(shown), id: \.self) { name in
                        URLSanitizerResultChip(text: name, kind: .kept)
                            .help(strings.otherHelp)
                    }
                }
            }
        }
        .frame(height: 22)
    }

    @ViewBuilder
    private var removedGroup: some View {
        if let result, !result.removals.isEmpty {
            let removals = result.removals
            fittedGroup(label: strings.trackers, count: removals.count,
                        hidden: { removals[$0...].map(\.name) }) { shown in
                ForEach(removals.prefix(shown), id: \.name) { removal in
                    removedChip(removal)
                }
            }
        } else {
            HStack(spacing: Self.gap) {
                groupLabel(strings.trackers)
                Text(result == nil ? strings.noneYet : strings.nothing)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .fixedSize()
        }
    }

    /// Candidates from every token down to none, each laid out at its ideal
    /// width; the first that fits the space it is offered wins.
    private func fittedGroup<Tokens: View>(label: String, count: Int, hidden: @escaping (Int) -> [String],
                                           @ViewBuilder tokens: @escaping (Int) -> Tokens) -> some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(stride(from: count, through: 0, by: -1)), id: \.self) { shown in
                HStack(spacing: Self.gap) {
                    groupLabel(label)
                    tokens(shown)
                    if shown < count {
                        let rest = hidden(shown)
                        URLSanitizerResultChip(text: "+\(rest.count)", kind: .overflow)
                            .help(rest.joined(separator: ", "))
                            .accessibilityLabel(rest.joined(separator: ", "))
                    }
                }
                .fixedSize()
            }
        }
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func removedChip(_ removal: URLCleaning.Removal) -> some View {
        let site = rules.site(id: removal.siteID)
        let siteName = site?.isGlobal == false ? site?.name ?? "" : strings.allSites
        return Button {
            openSite(removal.siteID)
        } label: {
            URLSanitizerResultChip(text: removal.name, kind: .removed)
        }
        .buttonStyle(.plain)
        .help(String(format: isPaused ? strings.wouldBeRemovedBy : strings.removedBy, siteName))
        .accessibilityLabel(String(format: isPaused ? strings.wouldRemoveTokenLabel : strings.removedTokenLabel,
                                   removal.name, siteName))
    }
}

struct URLSanitizerResultChip: View {
    enum Kind { case removed, kept, overflow }
    let text: String
    let kind: Kind

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .strikethrough(kind == .removed)
            .foregroundStyle(kind == .removed ? Color.red : Color.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(kind == .removed ? Color.red.opacity(0.12) : Color.primary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .contentShape(Rectangle())
    }
}

/// The left group takes the line minus whatever the right group, offered a
/// third of it, turns out to need.
private struct URLSanitizerResultLineLayout: Layout {
    let groupGap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 480
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let left = subviews.first else { return }
        var leftWidth = bounds.width
        if subviews.count > 1 {
            let right = subviews[1]
            let rightSize = right.sizeThatFits(ProposedViewSize(width: bounds.width / 3, height: nil))
            let rightWidth = min(rightSize.width, bounds.width / 3)
            right.place(at: CGPoint(x: bounds.maxX - rightWidth, y: bounds.midY), anchor: .leading,
                        proposal: ProposedViewSize(width: rightWidth, height: nil))
            leftWidth = max(0, bounds.width - rightWidth - groupGap)
        }
        left.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                   proposal: ProposedViewSize(width: leftWidth, height: nil))
    }
}
