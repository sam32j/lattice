// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The pieces the App Manager's tabs share: a scrolling page with an optional
/// footer docked under it, status cards, drop strips, chips and section
/// headers.
struct AppManagerPage<Content: View, Footer: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            footer()
        }
    }
}

extension AppManagerPage where Footer == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.footer = { EmptyView() }
    }
}

/// A footer docked under the page: a hairline above, the page's material
/// behind, and an optional progress line along its top edge.
struct AppManagerDockedFooter<Content: View>: View {
    var progress: Double? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 12) { content() }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(.bar)
            .overlay(alignment: .top) {
                ZStack(alignment: .leading) {
                    Divider()
                    if let progress {
                        GeometryReader { proxy in
                            Rectangle().fill(Color.accentColor)
                                .frame(width: proxy.size.width * min(max(progress, 0), 1), height: 2)
                                .animation(.easeOut(duration: 0.3), value: progress)
                        }
                        .frame(height: 2)
                    }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

enum AppManagerChipTone {
    case green, muted, purple, orange, accent, red

    var color: Color {
        switch self {
        case .green: return .green
        case .muted: return .secondary
        case .purple: return .purple
        case .orange: return .orange
        case .accent: return .accentColor
        case .red: return .red
        }
    }
}

struct AppManagerChip: View {
    let text: String
    var tone: AppManagerChipTone = .muted

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(tone == .muted ? AnyShapeStyle(.secondary) : AnyShapeStyle(tone.color))
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(tone == .muted ? Color.primary.opacity(0.07) : tone.color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

/// An app's own icon from its bundle, or a tinted tile with its initial.
struct AppManagerAppIcon: View {
    let path: String?
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let path, FileManager.default.fileExists(atPath: path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .overlay {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.42, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A symbol in a small tinted tile, for rows without an app icon.
struct AppManagerSymbolTile: View {
    let symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 30

    var body: some View {
        LatticeSymbol(symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The card heading a tab: what is happening and what to do about it.
struct AppManagerStatusCard<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    let headline: String
    let detail: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension AppManagerStatusCard where Leading == EmptyView {
    init(headline: String, detail: String?, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.leading = { EmptyView() }
        self.headline = headline
        self.detail = detail
        self.trailing = trailing
    }
}

/// A dashed strip that takes dropped files of the given types.
struct AppManagerDropStrip<Trailing: View>: View {
    let symbol: String
    var tint: Color = .accentColor
    let headline: String
    let detail: String
    let types: [UTType]
    let onDrop: ([URL]) -> Void
    @ViewBuilder var trailing: () -> Trailing
    @State private var targeted = false

    var body: some View {
        HStack(spacing: 12) {
            AppManagerSymbolTile(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(14)
        .background(targeted ? tint.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(targeted ? tint : Color.secondary.opacity(0.35),
                          style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
        .animation(.easeOut(duration: 0.15), value: targeted)
        .onDrop(of: types, isTargeted: $targeted) { providers in
            let group = DispatchGroup()
            var urls: [URL] = []
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { urls.append(url) } }
                    group.leave()
                }
            }
            group.notify(queue: .main) { onDrop(urls) }
            return true
        }
    }
}

/// A section's small heading above its card, with an optional trailing note.
struct AppManagerSectionHeader<Trailing: View>: View {
    let title: String
    var meta: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold))
            if let meta {
                Text("· \(meta)").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 4)
    }
}

extension AppManagerSectionHeader where Trailing == EmptyView {
    init(title: String, meta: String? = nil) {
        self.title = title
        self.meta = meta
        self.trailing = { EmptyView() }
    }
}

/// A notice inside a tab: orange for something to fix, blue for information.
struct AppManagerBanner<Trailing: View>: View {
    let title: String
    let detail: String
    var info = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(12)
        .background((info ? Color.accentColor : Color.orange).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder((info ? Color.accentColor : Color.orange).opacity(0.3)))
    }
}

/// A placeholder row while something loads.
struct AppManagerSkeletonRow: View {
    @State private var dim = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).frame(width: 130, height: 10)
                RoundedRectangle(cornerRadius: 3).frame(width: 200, height: 8)
            }
            Spacer()
            Capsule().frame(width: 62, height: 22)
        }
        .foregroundStyle(Color.primary.opacity(dim ? 0.05 : 0.1))
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { dim = true }
        }
        .accessibilityHidden(true)
    }
}

enum AppManagerFormat {
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    static func relative(_ date: Date, language: AppLanguage) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = language.formattingLocale()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// The App Manager's button: the capsule App Updates draws for "Update",
/// so the uninstaller and Homebrew read the same. Neutral for a way back,
/// red for removing, the accent for everything else.
struct AppManagerButtonStyle: ButtonStyle {
    enum Tone { case accent, destructive, neutral }
    var tone: Tone = .accent
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 3.5 : 5.5)
            .background(fill, in: Capsule())
            .foregroundStyle(tone == .neutral ? Color.primary : Color.white)
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }

    private var fill: Color {
        switch tone {
        case .accent: return .accentColor
        case .destructive: return .red
        case .neutral: return Color.primary.opacity(0.1)
        }
    }
}

extension ButtonStyle where Self == AppManagerButtonStyle {
    static func appManager(_ tone: AppManagerButtonStyle.Tone = .accent, compact: Bool = false) -> AppManagerButtonStyle {
        AppManagerButtonStyle(tone: tone, compact: compact)
    }
}

/// Placeholder rows inside a list's card while it loads: an icon tile, a
/// name and a detail line, and the button's capsule.
struct AppManagerListSkeleton: View {
    var rows = 5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(0..<rows, id: \.self) { index in
                if index > 0 { Rectangle().frame(height: 1).opacity(0.5) }
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 7).frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).frame(width: [120, 90, 150, 110, 135][index % 5], height: 10)
                        RoundedRectangle(cornerRadius: 3).frame(width: [200, 170, 220, 160, 190][index % 5], height: 8)
                    }
                    Spacer()
                    Capsule().frame(width: 62, height: 22)
                }
            }
        }
        .foregroundStyle(Color.primary.opacity(dim ? 0.05 : 0.1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { dim = true }
        }
        .accessibilityHidden(true)
    }
}

/// A search field with its filter at the trailing end, as Process Manager
/// and Homebrew show it. The whole filter area opens the menu.
struct AppManagerSearchField<Menu: View>: View {
    let placeholder: String
    @Binding var text: String
    var busy = false
    @ViewBuilder var menu: () -> Menu

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if busy { ProgressView().controlSize(.small) }
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 14)
                .accessibilityHidden(true)
            menu()
                .font(.system(size: 11.5))
        }
        .font(.system(size: 13))
        .padding(.leading, 10)
        .frame(minHeight: 37)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
}

/// The label of a search field's filter menu: the name and a chevron, with
/// the field's full height and some room as its target, not the text alone.
struct SearchFilterMenuLabel: View {
    let title: String
    var color: Color = .secondary
    /// Inside a search field the label takes the field's height and the
    /// room at its end as its target; elsewhere (the island's toolbar) it is
    /// the text alone, so it lines up with what sits beside it.
    var fillsField = true

    var body: some View {
        (Text(title + " ") + Text(Image(systemName: "chevron.down")).font(.system(size: 8, weight: .bold)))
            .foregroundStyle(color)
            .padding(.leading, fillsField ? 4 : 0)
            .padding(.trailing, fillsField ? 10 : 0)
            .padding(.vertical, fillsField ? 8 : 0)
            .contentShape(Rectangle())
    }
}
