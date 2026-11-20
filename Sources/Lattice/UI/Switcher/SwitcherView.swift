// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

private enum SwitcherIconStyle {
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceRaised = Color(nsColor: .windowBackgroundColor)
    static let tile = Color.primary.opacity(0.045)
    static let stroke = Color.primary.opacity(0.12)
    static let text = Color.primary
    static let secondaryText = Color.secondary
    static let thumbnailBackground = Color.primary.opacity(0.055)
}

/// The switcher's own backdrop: clear Liquid Glass that refracts, dimmed
/// and grayed so what sits on it reads.
///
/// The glass is the lens variant (11) at full strength: no blur, so nothing
/// turns to fog, and the native refraction at its edges. Every blurring style
/// tried, the system's own app-switcher subvariant included, read as fog, and
/// fading one glass over another doubled the image. The gray is a plain
/// neutral fill laid over the glass, never a second glass: it dims a light
/// desktop and lifts a black one toward the same gray. The lens's glowing rim
/// is clipped off, and a faint hairline keeps the outline. `.high` grays a
/// little more, for the layouts with thumbnails and the search field. Before
/// macOS 26, or with Reduce Transparency on, it falls back to the shared HUD
/// material.
struct SwitcherGlassBackdrop: View {
    let cornerRadius: CGFloat
    var contrast: HUDBackdrop.Contrast = .standard

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *),
           HUDBackdrop.drawsLiquidGlass(reduceTransparency: reduceTransparency) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            SwitcherLensGlass(cornerRadius: cornerRadius)
                .overlay(shape.fill(gray).allowsHitTesting(false))
                // A faint edge in place of the lens's glowing rim, so the
                // panel's outline holds over dark windows.
                .overlay(
                    shape.strokeBorder(colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.07),
                                       lineWidth: 0.5)
                        .allowsHitTesting(false)
                )
        } else {
            HUDBackdrop(cornerRadius: cornerRadius, contrast: contrast)
        }
#else
        HUDBackdrop(cornerRadius: cornerRadius, contrast: contrast)
#endif
    }

    /// A neutral gray rather than black or white: dark mode gets a deep gray
    /// that dims, light mode a pale one.
    private var gray: Color {
        let high = contrast == .high
        if colorScheme == .dark {
            return Color(white: 0.14).opacity(high ? 0.61 : 0.51)
        }
        return Color(white: 0.84).opacity(high ? 0.51 : 0.41)
    }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private struct SwitcherLensGlass: NSViewRepresentable {
    let cornerRadius: CGFloat

    /// The clear, refracting lens variant. It has no public name, so it is
    /// set only when the view still answers to it; otherwise the public
    /// `.clear` style stands in.
    static let lensVariant = 11
    /// The lens draws a glowing rim at its own edge. The glass is made this
    /// much larger than the shape and clipped back to it, so the glow falls
    /// outside while the refraction just inside the edge stays.
    static let rimOverhang: CGFloat = 4

    final class Container: NSView {
        let glass = NSGlassEffectView()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.masksToBounds = true
            layer?.cornerCurve = .continuous
            glass.style = .clear
            if glass.responds(to: NSSelectorFromString("set_variant:")) {
                glass.setValue(SwitcherLensGlass.lensVariant, forKey: "_variant")
            }
            addSubview(glass)
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            let overhang = SwitcherLensGlass.rimOverhang
            glass.frame = bounds.insetBy(dx: -overhang, dy: -overhang)
        }
    }

    func makeNSView(context: Context) -> Container {
        let view = Container(frame: .zero)
        apply(to: view)
        return view
    }

    func updateNSView(_ view: Container, context: Context) {
        apply(to: view)
    }

    private func apply(to view: Container) {
        view.layer?.cornerRadius = cornerRadius
        view.glass.cornerRadius = cornerRadius + Self.rimOverhang
        view.needsLayout = true
    }
}
#endif

/// A window's name laid over the bottom of its thumbnail: white on a dark,
/// rounded plate, so it reads over any picture and over any glass, and the
/// thumbnail keeps the room a band under it would take.
private struct SwitcherWindowTitlePill: View {
    let title: String
    /// The app's icon at the start of the line, standing in for its name so
    /// the label stays one row.
    var icon: NSImage? = nil
    let isSelected: Bool
    /// When set, a name longer than this scrolls while `scrolls` is on (the
    /// pointer is on the card) instead of losing its middle to an ellipsis.
    var maxTitleWidth: CGFloat? = nil
    var scrolls = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            }
            if let maxTitleWidth {
                let weight: Font.Weight = isSelected ? .semibold : .regular
                ScrollingTitle(text: title,
                               weight: weight,
                               width: min(maxTitleWidth,
                                          SwitcherSupport.titleWidth(title, weight: isSelected ? .semibold : .regular)
                                              .rounded(.up) + 1),
                               alignment: .center,
                               scrolls: scrolls)
            } else {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(Color.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(isSelected ? 0.72 : 0.6))
        )
    }
}

/// Where the shown window sits among its app's windows in a grouped grid
/// cell: one dash per window, the current one longer and brighter. The long
/// dash slides to the next window as the card cross-fades.
private struct SwitcherWindowPageDots: View {
    let position: Int
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(count, 8), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(index == position ? 0.95 : 0.42))
                    .frame(width: index == position ? 16 : 6, height: 3)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(Color.black.opacity(0.55)))
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: position)
        .accessibilityHidden(true)
    }
}

/// The search field's text cursor: a thin bar that blinks at the usual text
/// cursor pace (on, then off, about half a second each), shown while the
/// field is active.
private struct SwitcherSearchCaret: View {
    static let blinkInterval: TimeInterval = 0.53

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.periodic(from: start, by: Self.blinkInterval)) { context in
            let phase = Int(context.date.timeIntervalSince(start) / Self.blinkInterval)
            RoundedRectangle(cornerRadius: 0.75)
                .fill(Color.accentColor)
                .frame(width: 1.5, height: 14)
                .opacity(reduceMotion || phase % 2 == 0 ? 1 : 0)
        }
        .accessibilityHidden(true)
    }
}

/// A window card's close button: a red-tinted glass button with a plain x.
/// The glass supplies the circle and its edge, so the x has no outline of
/// its own; hovering keeps the same button and lets the glass respond.
private struct SwitcherCloseButtonLabel: View {
    let size: CGFloat

    private static let red = Color(red: 1.0, green: 0.36, blue: 0.32)

    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(fill)
            .contentShape(Circle())
    }

    @ViewBuilder
    private var fill: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Circle()
                .fill(Color.clear)
                .glassEffect(.regular.tint(Self.red).interactive(), in: Circle())
        } else {
            Circle().fill(Self.red)
        }
#else
        Circle().fill(Self.red)
#endif
    }
}

/// The one selection look every switcher tile shares, taken from the system
/// switcher: a soft gray rounded backdrop, no accent-colored outline.
private struct SwitcherSelectionBackdrop: View {
    enum Kind {
        /// App icons: a darker gray on light glass and a paler one on dark
        /// glass, so a small tile stands out from the dimmed backdrop.
        case app
        /// Window thumbnails: the subtler gray, since the card is large and
        /// its picture already carries contrast.
        case window
    }

    let isSelected: Bool
    let cornerRadius: CGFloat
    var kind: Kind = .app

    @Environment(\.colorScheme) private var colorScheme

    private var fill: Color {
        switch kind {
        case .app: return colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.2)
        case .window: return Color.primary.opacity(0.14)
        }
    }

    private var stroke: Color {
        Color.primary.opacity(kind == .app ? 0.08 : 0.10)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isSelected ? fill : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? stroke : Color.clear, lineWidth: 0.5)
            )
    }
}

/// Drops a SwiftUI shadow when the surface is Liquid Glass: the glass casts
/// its own, and `.shadow` would render it offscreen and frost it.
private struct SwitcherSurfaceShadow: ViewModifier {
    let opacity: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if HUDBackdrop.drawsLiquidGlass(reduceTransparency: reduceTransparency) {
            content
        } else {
            content.shadow(color: Color.black.opacity(opacity), radius: 10, x: 0, y: 5)
        }
    }
}

/// A panel of the icon row. Those panels float on the desktop on their own
/// instead of sitting inside one backdrop like the window grid, so each one
/// draws its own: Liquid Glass when the app's setting asks for it, the solid
/// surface otherwise.
private struct SwitcherIconRowSurface: View {
    let cornerRadius: CGFloat
    let fill: Color
    var stroke: Color = SwitcherIconStyle.stroke
    var contrast: HUDBackdrop.Contrast = .standard

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if HUDBackdrop.drawsLiquidGlass(reduceTransparency: reduceTransparency) {
            // The backdrop draws its own edge.
            SwitcherGlassBackdrop(cornerRadius: cornerRadius, contrast: contrast)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(stroke, lineWidth: 1)
                )
        }
    }
}

private struct SwitcherHiddenAppBadge: ViewModifier {
    let isHidden: Bool
    let size: CGFloat

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isHidden {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: size * 0.48, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.black.opacity(0.72)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.68), lineWidth: 1))
                    .accessibilityHidden(true)
            }
        }
    }
}

private extension View {
    func switcherHiddenAppBadge(_ isHidden: Bool, size: CGFloat) -> some View {
        modifier(SwitcherHiddenAppBadge(isHidden: isHidden, size: size))
    }
}

/// Content of the switcher panel: a grid of large window cards with live
/// thumbnails, hover/keyboard selection and an optional springy highlight.
struct SwitcherView: View {
    @EnvironmentObject private var switcher: AppSwitcher
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.minimalWindowPreviews) private var minimalPreviews = false
    @AppStorage(DefaultsKey.switcherIconRowMode) private var iconRowMode = false
    @AppStorage(DefaultsKey.switcherSimpleMode) private var simpleMode = false
    @AppStorage(DefaultsKey.switcherInstantSelection) private var instantSelection = false
    @AppStorage(DefaultsKey.switcherCurrentSpaceOnly) private var currentSpaceOnly = false
    @AppStorage(DefaultsKey.switcherShortcut) private var switcherShortcutStorage = GlobalShortcut.switcherDefault.storageValue
    @AppStorage(DefaultsKey.switcherWindowShortcut) private var switcherWindowShortcutStorage = GlobalShortcut.switcherWindowDefault.storageValue

    var body: some View {
        // The icon layouts keep their own panel even with nothing to list, so
        // a search with no matches never swaps the row for a different shape.
        if SwitcherSupport.usesIconRowLayout(iconRowMode: iconRowMode,
                                             simpleMode: simpleMode,
                                             sessionScope: switcher.sessionScope) {
            iconRowPanel
        } else {
            standardPanel
        }
    }

    private var standardPanel: some View {
        Group {
            if switcher.windows.isEmpty {
                emptyState
            } else {
                cardGrid
            }
        }
        .padding(SwitcherGrid.padding)
        .padding(.top, switcher.searchTopInset)
        // The grid keeps the size it opened with while a search thins it out:
        // matches fill it from the top, and no matches show inside it.
        .frame(width: switcher.grid.panelSize.width,
               height: switcher.grid.panelSize.height + switcher.searchTopInset,
               alignment: .top)
        // Clip the cards, not the glass: clipping the glass renders it
        // offscreen and frosts it. The glass rounds its own corners.
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(SwitcherGlassBackdrop(cornerRadius: 24, contrast: .high))
        .overlay(alignment: .top) {
            searchChip
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(minimalPreviews ? Color.clear : SwitcherIconStyle.stroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if switcher.searchQuery.isEmpty {
            Text(l10n.s.switcherNoWindows)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(switcher.searchQuery)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: SwitcherGrid.cardWidth - 36)
                Text("0/\(switcher.totalWindowCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var iconRowPanel: some View {
        iconRowSwitcher
            .padding(.top, switcher.searchTopInset)
            .frame(width: iconRowPanelSize.width,
                   height: iconRowPanelSize.height + switcher.searchTopInset,
                   alignment: .top)
            .overlay(alignment: .top) {
                // The simple layout shows the field only once something is
                // typed; at rest it is just the row, like the system switcher.
                if !simpleMode || !switcher.searchQuery.isEmpty {
                    searchChip
                }
            }
    }

    /// Always on screen and centered, like a search field waiting for input:
    /// it stays subdued until the first character typed fills it.
    @ViewBuilder
    private var searchChip: some View {
        let isSearching = !switcher.searchQuery.isEmpty || switcher.isSearchActivated
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .fixedSize()
            let hasQuery = !switcher.searchQuery.isEmpty
            HStack(spacing: 1) {
                // An empty active field shows the cursor where typing will
                // start, ahead of the placeholder, as a text field does.
                if isSearching, !hasQuery { SwitcherSearchCaret() }
                Text(hasQuery ? switcher.searchQuery : l10n.s.switcherSearchPlaceholder)
                    .font(.system(size: 12, weight: hasQuery ? .semibold : .regular))
                    .foregroundStyle(hasQuery ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .truncationMode(.head)
                if hasQuery { SwitcherSearchCaret() }
            }
            .frame(minWidth: 0, maxWidth: 220)
            if hasQuery {
                Text("\(switcher.windows.count)/\(switcher.totalWindowCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .foregroundStyle(isSearching ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 12)
        .frame(minWidth: SwitcherSearchLayout.minimumWidth, minHeight: SwitcherSearchLayout.chipHeight,
               maxHeight: SwitcherSearchLayout.chipHeight)
        .background(
            SwitcherIconRowSurface(cornerRadius: SwitcherSearchLayout.chipHeight / 2,
                                   fill: SwitcherIconStyle.surfaceRaised,
                                   contrast: .high)
        )
        .animation(.easeOut(duration: 0.15), value: isSearching)
        .contentShape(Capsule(style: .continuous))
        // Clicking the field activates it and pins the panel, like typing.
        .onTapGesture { switcher.activateSearch() }
        .padding(SwitcherSearchLayout.edgeInset)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSearchField)
    }

    /// One grid cell: a window, or with "Group windows by app" an app showing
    /// the window currently picked among its own.
    private struct GridCell: Identifiable {
        let id: AnyHashable
        let index: Int
        let windowPosition: Int
        let windowCount: Int
    }

    private var gridCells: [GridCell] {
        guard switcher.groupsGridByApp else {
            return switcher.windows.indices.map {
                GridCell(id: AnyHashable(switcher.windows[$0].id), index: $0, windowPosition: 0, windowCount: 1)
            }
        }
        let windows = switcher.windows
        return appGroups.map { group in
            let members = windows.indices.filter { windows[$0].pid == group.pid }
            let shown = members.contains(switcher.selectedIndex) ? switcher.selectedIndex : group.representativeIndex
            return GridCell(id: AnyHashable(group.pid), index: shown,
                            windowPosition: members.firstIndex(of: shown) ?? 0,
                            windowCount: members.count)
        }
    }

    private func gridScrollID(for index: Int) -> AnyHashable? {
        guard switcher.windows.indices.contains(index) else { return nil }
        return switcher.groupsGridByApp ? AnyHashable(switcher.windows[index].pid)
                                        : AnyHashable(switcher.windows[index].id)
    }

    private var cardGrid: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // Not a LazyVGrid: a lazy grid cannot animate a reflow, so
                // after a close its cards jumped or flew in from the edge.
                SwitcherCardGridLayout(columns: switcher.grid.columns,
                                       cardSize: CGSize(width: SwitcherGrid.cardWidth,
                                                        height: SwitcherGridCard.height),
                                       spacing: SwitcherGrid.spacing) {
                    ForEach(gridCells) { cell in
                        let index = cell.index
                        let window = switcher.windows[index]
                        WindowCard(window: window,
                                   preview: window.previewWindowID.flatMap { switcher.previews[$0] },
                                   isSelected: index == switcher.selectedIndex,
                                   animatesSelection: !instantSelection,
                                   onCommit: {
                                       switcher.select(index: index)
                                       switcher.commitSession()
                                   },
                                   onClose: {
                                       switcher.closeWindow(window)
                                   })
                            // In a grouped cell the window shortcut swaps the
                            // card's window in place with a cross-fade.
                            .id(window.id)
                            .transition(.opacity)
                            .overlay(alignment: .top) {
                                if cell.windowCount > 1 {
                                    SwitcherWindowPageDots(position: cell.windowPosition, count: cell.windowCount)
                                        .padding(.top, SwitcherGridCard.padding + 6)
                                }
                            }
                            .frame(width: SwitcherGrid.cardWidth, height: SwitcherGridCard.height)
                            .clipped()
                            .animation(instantSelection ? nil : .easeInOut(duration: 0.22),
                                       value: window.id)
                            .id(cell.id)
                            // A closed window's card fades out where it was
                            // while the rest slide over it.
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                            .onHover { hovering in
                                if hovering {
                                    switcher.hoverSelect(index: index)
                                } else {
                                    switcher.hoverSelectEnded(index: index)
                                }
                            }
                    }
                }
            }
            .scrollDisabled(switcher.grid.rows <= switcher.grid.visibleRows)
            // Like the wrapped icon rows: a reverse start selects the last card
            // before the grid exists, so reveal it on appear too.
            .onAppear {
                guard let id = gridScrollID(for: switcher.selectedIndex) else { return }
                proxy.scrollTo(id, anchor: nil)
            }
            .onChange(of: switcher.selectedIndex) { _, newIndex in
                guard let id = gridScrollID(for: newIndex) else { return }
                withAnimation(instantSelection ? nil : .easeOut(duration: 0.15)) {
                    proxy.scrollTo(id, anchor: nil)
                }
            }
        }
    }

    /// The app row is its own glass container, like the system switcher.
    /// For Large icons the selected app's windows float in a second, separate
    /// panel under the row and follow the selected icon: keeping the two apart
    /// keeps the row light, and putting the thumbnails below leaves the icons
    /// near the middle of the screen, where ⌘Tab puts them.
    private var iconRowSwitcher: some View {
        VStack(spacing: SwitcherIconRowLayout.previewGap) {
            iconRow
                .padding(.horizontal, SwitcherIconRowLayout.rowHorizontalPadding)
                .frame(width: switcher.iconRowLayout.appRowSurfaceWidth,
                       height: switcher.iconRowLayout.iconAreaHeight)
                .background(
                    SwitcherGlassBackdrop(cornerRadius: SwitcherIconRowLayout.containerCornerRadius)
                )
            if !simpleMode {
                selectedAppPreviewPanel
            }
        }
        .frame(width: iconRowContentWidth, alignment: .top)
        .padding(SwitcherIconRowLayout.padding)
    }

    private var iconRowPanelSize: CGSize {
        simpleMode ? switcher.iconRowLayout.simplePanelSize : switcher.iconRowLayout.panelSize
    }

    private var usesWindowRow: Bool {
        SwitcherSupport.usesWindowRow(simpleMode: simpleMode,
                                      sessionScope: switcher.sessionScope)
    }

    /// The selected app's windows, in a panel of their own under the row
    /// that slides to sit beneath the selected icon. Its thumbnails
    /// cross-fade when the selection moves to another app.
    @ViewBuilder
    private var selectedAppPreviewPanel: some View {
        if selectedWindow != nil {
            let appWindows = selectedAppWindows
            let placement = selectedPreviewPlacement
            ZStack(alignment: .topLeading) {
                Group {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: SwitcherIconRowLayout.spacing) {
                                ForEach(appWindows, id: \.element.id) { index, window in
                                    SwitcherWindowPreviewTile(window: window,
                                                              preview: window.previewWindowID.flatMap { switcher.previews[$0] },
                                                              isSelected: index == switcher.selectedIndex,
                                                              instantSelection: instantSelection,
                                                              onCommit: {
                                                                  switcher.select(index: index)
                                                                  switcher.commitSession()
                                                              },
                                                              onClose: {
                                                                  switcher.closeWindow(window)
                                                              })
                                        .id(window.id)
                                        .onHover { hovering in
                                            if hovering {
                                                switcher.hoverSelect(index: index)
                                            } else {
                                                switcher.hoverSelectEnded(index: index)
                                            }
                                        }
                                    }
                                }
                            .frame(height: SwitcherIconRowLayout.previewCardHeight, alignment: .center)
                        }
                        .scrollDisabled(switcher.iconRowLayout.previewFitsWithoutScrolling(cardCount: appWindows.count))
                        .frame(width: switcher.iconRowLayout.previewContentWidth,
                               height: SwitcherIconRowLayout.previewCardHeight)
                        .onAppear { revealSelection(in: proxy, animated: false) }
                        .onChange(of: switcher.selectedIndex) { _, _ in
                            revealSelection(in: proxy, animated: true)
                        }
                        .onChange(of: appWindows.map(\.element.id)) { _, _ in
                            revealSelection(in: proxy, animated: true)
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _ in
                            DispatchQueue.main.async {
                                revealSelection(in: proxy, animated: false)
                            }
                        }
                    }
                }
                .id(selectedWindow?.pid)
                .transition(.opacity)
                .padding(SwitcherIconRowLayout.previewPanelPadding)
                .frame(width: switcher.iconRowLayout.previewSurfaceWidth,
                       height: SwitcherIconRowLayout.previewHeight)
                .background(
                    SwitcherGlassBackdrop(cornerRadius: SwitcherIconRowLayout.previewPanelCornerRadius,
                                          contrast: .high)
                )
                .offset(x: placement.leading)
            }
            .frame(width: placement.contentWidth,
                   height: SwitcherIconRowLayout.previewHeight,
                   alignment: .topLeading)
            // Snappy, not a glide: the panel should land under the next app
            // about as fast as the selection moves there.
            .animation(instantSelection ? nil : .snappy(duration: 0.16), value: selectedWindow?.pid)
        }
    }

    @ViewBuilder
    private var iconRow: some View {
        if switcher.windows.isEmpty {
            iconRowEmptyState
        } else if usesWindowRow {
            windowIconRow
        } else {
            appIconRow
        }
    }

    /// Nothing to list, or nothing matching the search: said inside the row,
    /// which keeps its size.
    private var iconRowEmptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .opacity(switcher.searchQuery.isEmpty ? 0 : 1)
            Text(switcher.searchQuery.isEmpty ? l10n.s.switcherNoWindows : switcher.searchQuery)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appIconRow: some View {
        let groups = appGroups
        let dividerPIDs = SwitcherSupport.windowlessAppDividerPIDs(items: switcher.windows)
        return overflowingIconRow(
            itemCount: groups.count,
            tileWidth: SwitcherIconRowLayout.appTileWidth
        ) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { position, group in
                let index = group.representativeIndex
                let window = switcher.windows[index]
                SwitcherSystemTile(window: window,
                                   isSelected: group.pid == selectedWindow?.pid,
                                   animatesSelection: !instantSelection,
                                   onCommit: {
                                       switcher.select(index: index)
                                       switcher.commitSession()
                                   })
                    .overlay(alignment: .leading) {
                        // A wrapped row's first icon has no gap to its left
                        // to draw in; the divider would land outside the grid.
                        if dividerPIDs.contains(group.pid),
                           position % switcher.iconRowLayout.columns != 0 || !switcher.iconRowLayout.isWrapped {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor))
                                .frame(width: 1, height: SwitcherIconRowLayout.selectedIconSize * 0.6)
                                // Occupy the existing gap so scrolling and hit targets stay aligned.
                                .offset(x: -(SwitcherIconRowLayout.spacing + 1) / 2)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .id(group.pid)
                    .onHover { hovering in
                        if hovering {
                            switcher.hoverSelectIconRow(index: index)
                        } else {
                            switcher.hoverSelectIconRowEnded(index: index)
                        }
                    }
            }
        }
    }

    private var windowIconRow: some View {
        overflowingIconRow(
            itemCount: switcher.windows.count,
            tileWidth: SwitcherIconRowLayout.windowTileWidth
        ) {
            ForEach(Array(switcher.windows.enumerated()), id: \.element.id) { index, window in
                SwitcherIconTile(
                    window: window,
                    isSelected: index == switcher.selectedIndex,
                    animatesSelection: !instantSelection,
                    onCommit: {
                        switcher.select(index: index)
                        switcher.commitSession()
                    }
                )
                .id(window.id)
                .onHover { hovering in
                    if hovering {
                        switcher.hoverSelectIconRow(index: index)
                    } else {
                        switcher.hoverSelectIconRowEnded(index: index)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func overflowingIconRow<Content: View>(itemCount: Int,
                                                   tileWidth: CGFloat,
                                                   @ViewBuilder content: () -> Content) -> some View {
        if switcher.iconRowLayout.isWrapped {
            wrappedIconRows(tileWidth: tileWidth, content: content)
        } else {
            singleIconRow(itemCount: itemCount, tileWidth: tileWidth, content: content)
        }
    }

    /// The icons wrapped at the user's column cap. Rows past what the screen
    /// holds scroll, following the selection like the card grid does.
    private func wrappedIconRows<Content: View>(tileWidth: CGFloat,
                                                @ViewBuilder content: () -> Content) -> some View {
        let layout = switcher.iconRowLayout
        let tiles = content()
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(tileWidth),
                                                       spacing: SwitcherIconRowLayout.spacing),
                                   count: layout.columns),
                    spacing: 0
                ) {
                    tiles
                        .frame(height: SwitcherIconRowLayout.rowHeight)
                }
            }
            .scrollDisabled(layout.rows <= layout.visibleRows)
            // The reverse shortcut opens on the last item, which is selected
            // before this view exists, so no change fires to reveal it.
            .onAppear { revealSelectedIcon(in: proxy, animated: false) }
            // Follow the selected icon rather than the index: a search can keep
            // the index while the item under it, and so its row, changes.
            .onChange(of: selectedIconScrollID) { _, _ in
                revealSelectedIcon(in: proxy, animated: true)
            }
            .onChange(of: layout.rows) { _, _ in
                revealSelectedIcon(in: proxy, animated: false)
            }
        }
        .frame(width: layout.appRowContentWidth, height: layout.iconAreaHeight)
        .contentShape(Rectangle())
    }

    private var selectedIconScrollID: AnyHashable? {
        SwitcherSupport.iconRowScrollID(items: switcher.windows,
                                        selectedIndex: switcher.selectedIndex,
                                        windowRow: usesWindowRow)
    }

    /// Same guard as `revealSelection`: before macOS 26 an animated scroll can
    /// be dropped during fast navigation, so those versions scroll at once.
    private func revealSelectedIcon(in proxy: ScrollViewProxy, animated: Bool) {
        guard let id = selectedIconScrollID else { return }
        guard animated, !instantSelection, #available(macOS 26, *) else {
            proxy.scrollTo(id, anchor: nil)
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(id, anchor: nil)
        }
    }

    private func singleIconRow<Content: View>(itemCount: Int,
                                              tileWidth: CGFloat,
                                              @ViewBuilder content: () -> Content) -> some View {
        let layout = switcher.iconRowLayout
        let overflow = itemCount > layout.visibleIconCount
        // Tiles are laid out at full size, then shrunk as one so every app
        // fits on the row, the way the system switcher shrinks its icons.
        let scale = max(layout.tileScale, SwitcherIconRowLayout.minimumTileScale)
        return HStack(alignment: .center, spacing: SwitcherIconRowLayout.spacing) {
            content()
        }
        .frame(height: SwitcherIconRowLayout.rowHeight, alignment: .center)
        .offset(x: overflow ? iconRowOverflowOffset(tileWidth: tileWidth) : 0)
        .animation(instantSelection ? nil : .easeOut(duration: SwitcherSupport.iconRowEdgeHoverAnimationDuration),
                   value: switcher.iconRowFirstVisibleIndex)
        // A search can leave fewer tiles than the row was sized for; they
        // gather in the middle rather than against one end.
        .frame(width: layout.appRowContentWidth / scale,
               height: SwitcherIconRowLayout.rowHeight,
               alignment: overflow ? .leading : .center)
        .clipped()
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: layout.appRowContentWidth,
               height: SwitcherIconRowLayout.rowHeight * scale,
               alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func iconRowOverflowOffset(tileWidth: CGFloat) -> CGFloat {
        let first = switcher.iconRowFirstVisibleIndex
        return -CGFloat(first) * (tileWidth + SwitcherIconRowLayout.spacing)
    }

    private var selectedWindow: SwitcherItem? {
        guard switcher.windows.indices.contains(switcher.selectedIndex) else { return nil }
        return switcher.windows[switcher.selectedIndex]
    }

    /// A search can resize the strip without moving the selection, and closing
    /// a window can replace the selected item at the same index. Reveal after
    /// the viewport's actual geometry changes, allowing its native scroll view
    /// to finish resizing before the queued reveal reads the current selection.
    /// Resize corrections are unanimated. SwiftUI before macOS 26 can also drop
    /// animated reveals during rapid navigation, so use immediate scrolling there.
    private func revealSelection(in proxy: ScrollViewProxy, animated: Bool) {
        let index = switcher.selectedIndex
        guard switcher.windows.indices.contains(index) else { return }
        let id = switcher.windows[index].id
        guard animated, !instantSelection, NSApp.activationPolicy() != .prohibited, #available(macOS 26, *) else {
            proxy.scrollTo(id, anchor: .center)
            return
        }
        // A soft spring rather than a quick ease: the strip glides to center
        // the next window, so the eye can follow where the selection went.
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private var selectedAppWindows: [(offset: Int, element: SwitcherItem)] {
        guard let selectedWindow else { return [] }
        return Array(switcher.windows.enumerated()).filter { $0.element.pid == selectedWindow.pid }
    }

    private var appGroups: [SwitcherAppGroup] {
        SwitcherSupport.appGroups(items: switcher.windows, currentSpaceOnly: currentSpaceOnly)
    }

    private var iconRowContentWidth: CGFloat {
        switcher.iconRowLayout.contentWidth(simpleMode: simpleMode)
    }

    private var selectedPreviewPlacement: SwitcherIconRowPreviewPlacement {
        let groups = appGroups
        let selectedIndex = selectedWindow
            .flatMap { selected in groups.firstIndex { $0.pid == selected.pid } }
            ?? 0
        let placement = SwitcherSupport.selectedPreviewPlacement(
            appCount: groups.count,
            selectedAppIndex: selectedIndex,
            selectedWindowIndex: selectedAppWindows.firstIndex { $0.offset == switcher.selectedIndex } ?? 0,
            selectedWindowCount: selectedAppWindows.count,
            visibleIconCount: switcher.iconRowLayout.visibleIconCount,
            appRowContentWidth: switcher.iconRowLayout.appRowContentWidth,
            appRowSurfaceWidth: switcher.iconRowLayout.appRowSurfaceWidth,
            previewContentWidth: switcher.iconRowLayout.previewContentWidth,
            previewSurfaceWidth: switcher.iconRowLayout.previewSurfaceWidth,
            columns: switcher.iconRowLayout.isWrapped ? switcher.iconRowLayout.columns : nil,
            tileScale: switcher.iconRowLayout.tileScale
        )
        // A search can leave fewer icons than the row was sized for, and they
        // sit centered in it; shift the panel by the same amount so it stays
        // under the selected icon.
        let layout = switcher.iconRowLayout
        guard groups.count <= layout.visibleIconCount, !layout.isWrapped else { return placement }
        let natural = (CGFloat(groups.count) * SwitcherIconRowLayout.appTileWidth
            + CGFloat(max(0, groups.count - 1)) * SwitcherIconRowLayout.spacing) * layout.tileScale
        let shift = max(0, (layout.appRowContentWidth - natural) / 2)
        let leading = min(max(0, placement.leading + shift),
                          max(0, placement.contentWidth - layout.previewSurfaceWidth))
        return SwitcherIconRowPreviewPlacement(contentWidth: placement.contentWidth, leading: leading)
    }
}

/// The app tile of both icon layouts, drawn like the system ⌘Tab switcher:
/// a large icon, a soft gray square behind the selected one, and the app's
/// name under the selection only, kept inside the tile.
private struct SwitcherSystemTile: View {
    let window: SwitcherItem
    let isSelected: Bool
    let animatesSelection: Bool
    let onCommit: () -> Void

    @ObservedObject private var l10n = L10n.shared

    private var box: CGFloat { SwitcherIconRowLayout.appTileWidth }
    /// The system square's corner follows the icon's own curve outward.
    private var cornerRadius: CGFloat { SwitcherIconRowLayout.selectionCornerRadius }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: SwitcherIconRowLayout.rowBand)
            // The square is the tile's own size. The icon's frame is larger
            // (its image carries a transparent margin), so it overhangs the
            // square instead of the square growing to the frame and spilling
            // past the tile, where the row's edge would cut it off.
            Color.clear
                .frame(width: box, height: box)
                .background(SwitcherSelectionBackdrop(isSelected: isSelected, cornerRadius: cornerRadius))
                .overlay {
                    if let icon = window.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: SwitcherIconRowLayout.iconSize,
                                   height: SwitcherIconRowLayout.iconSize)
                            .switcherHiddenAppBadge(window.isAppHidden, size: 20)
                    }
                }
            // Only the selection is named, within its own tile so the row's
            // edge never cuts it off.
            Text(isSelected ? window.appName : " ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SwitcherIconStyle.text)
                .shadow(color: Color.black.opacity(0.25), radius: 1.5, y: 0.5)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: box, height: SwitcherIconRowLayout.rowBand)
        }
        .frame(width: box, height: SwitcherIconRowLayout.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: onCommit)
        .animation(animatesSelection ? .easeOut(duration: 0.12) : nil, value: isSelected)
        .accessibilityLabel(window.isAppHidden ? "\(window.appName), \(l10n.s.panelHiddenItem)" : window.appName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A window in the window row (⌘` in the simple layout): the app's icon with
/// the window's own title under it, kept inside the tile, and the same gray
/// selection as the app tiles.
private struct SwitcherIconTile: View {
    let window: SwitcherItem
    let isSelected: Bool
    let animatesSelection: Bool
    let onCommit: () -> Void

    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: SwitcherIconRowLayout.iconTileSpacing) {
            ZStack(alignment: .topTrailing) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: SwitcherIconRowLayout.iconSize,
                               height: SwitcherIconRowLayout.iconSize)
                        .switcherHiddenAppBadge(window.isAppHidden, size: 20)
                }
                if window.isOnHiddenSpace {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 18, height: 16)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.gray))
                        .offset(x: 1, y: -1)
                } else if window.isMinimized || window.isFullscreen {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 12, height: 12)
                        .offset(x: 1, y: -1)
                }
            }
            .frame(width: SwitcherIconRowLayout.selectedIconSize,
                   height: SwitcherIconRowLayout.selectedIconSize)
            // Like the app tiles, the selection wraps the icon alone, its
            // corner running parallel to the icon's.
            .background(SwitcherSelectionBackdrop(isSelected: isSelected,
                                                  cornerRadius: SwitcherIconRowLayout.selectionCornerRadius))
            Text(window.displayTitle)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? SwitcherIconStyle.text : SwitcherIconStyle.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: SwitcherIconRowLayout.windowLabelWidth,
                       height: SwitcherIconRowLayout.iconTitleHeight)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, SwitcherIconRowLayout.iconTileVerticalPadding)
        .contentShape(Rectangle())
        .onTapGesture(perform: onCommit)
        .animation(animatesSelection ? .easeOut(duration: 0.12) : nil, value: isSelected)
        .accessibilityLabel(window.spokenLabel(noOpenWindow: l10n.s.switcherNoOpenWindow,
                                               hiddenApp: l10n.s.panelHiddenItem,
                                               otherDesktop: l10n.s.switcherOtherDesktop))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SwitcherWindowPreviewTile: View {
    let window: SwitcherItem
    let preview: CGImage?
    let isSelected: Bool
    let instantSelection: Bool
    let onCommit: () -> Void
    let onClose: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.minimalWindowPreviews) private var minimalPreviews = false
    @State private var isHovering = false
    @State private var suppressNextCommit = false

    private var hasStatusBadges: Bool {
        window.isMinimized || window.isFullscreen || window.isOnHiddenSpace
    }

    private var showsCloseButton: Bool {
        !minimalPreviews && isHovering && window.windowID != nil
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(minimalPreviews ? Color.clear : SwitcherIconStyle.thumbnailBackground)

                if let preview {
                    Image(decorative: preview, scale: 2)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(5)
                } else if window.isAppEntry, let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: SwitcherIconRowLayout.appEntryIconSize,
                               height: SwitcherIconRowLayout.appEntryIconSize)
                        .switcherHiddenAppBadge(window.isAppHidden, size: 18)
                } else if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .switcherHiddenAppBadge(window.isAppHidden, size: 20)
                }

                // The window's name, one line, centered along the bottom of
                // the picture; its state in the top corner. The selected icon
                // already names the app, so a window with no name of its own
                // gets no label.
                if !minimalPreviews {
                    VStack(spacing: 0) {
                        HStack {
                            if hasStatusBadges {
                                HStack(spacing: 5) {
                                    statusBadges
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                        if let detail = window.windowDetail(noOpenWindow: l10n.s.switcherNoOpenWindow) {
                            SwitcherWindowTitlePill(title: detail, isSelected: isSelected)
                        }
                    }
                    .padding(8)
                }

                VStack {
                    HStack {
                        Spacer()
                        closeButton
                            .padding(5)
                    }
                    Spacer()
                }
            }
            .frame(width: SwitcherIconRowLayout.previewCardWidth - 8,
                   height: SwitcherIconRowLayout.previewCardHeight - 8)
        }
        .padding(4)
        .frame(width: SwitcherIconRowLayout.previewCardWidth,
               height: SwitcherIconRowLayout.previewCardHeight)
        .background(SwitcherSelectionBackdrop(isSelected: isSelected, cornerRadius: 14, kind: .window))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            guard !suppressNextCommit else { return }
            onCommit()
        }
        .onHover { isHovering = $0 }
        .animation(instantSelection ? nil : .easeOut(duration: 0.12), value: showsCloseButton)
        .accessibilityLabel(window.spokenLabel(noOpenWindow: l10n.s.switcherNoOpenWindow,
                                               hiddenApp: l10n.s.panelHiddenItem,
                                               otherDesktop: l10n.s.switcherOtherDesktop))
    }

    @ViewBuilder
    private var closeButton: some View {
        if showsCloseButton {
            Button {
                suppressNextCommit = true
                onClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    suppressNextCommit = false
                }
            } label: {
                SwitcherCloseButtonLabel(size: 22)
            }
            .buttonStyle(.plain)
            .help(l10n.s.dockPreviewCloseWindow)
            .accessibilityLabel(l10n.s.dockPreviewCloseWindow)
        }
    }

    private var statusBadges: some View {
        HStack(spacing: 4) {
            if window.isMinimized {
                statusBadge(systemName: "minus.rectangle")
            }
            if window.isFullscreen {
                statusBadge(systemName: "arrow.up.left.and.arrow.down.right")
            }
            if window.isOnHiddenSpace {
                statusBadge(systemName: "rectangle.stack")
            }
        }
    }

    private func statusBadge(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.9))
            .frame(width: 20, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.46))
            )
            .accessibilityHidden(true)
    }
}

private struct WindowCard: View {
    let window: SwitcherItem
    let preview: CGImage?
    let isSelected: Bool
    let animatesSelection: Bool
    let onCommit: () -> Void
    let onClose: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.minimalWindowPreviews) private var minimalPreviews = false
    @State private var isHovering = false
    @State private var suppressNextCommit = false

    private var showsCloseButton: Bool {
        !minimalPreviews && isHovering && window.windowID != nil
    }

    private var hasStatusBadges: Bool {
        window.isMinimized || window.isFullscreen || window.isOnHiddenSpace
    }

    /// Without a thumbnail the app icon already fills the card, so the small
    /// corner badge would only repeat it.
    private var showsAppBadge: Bool {
        preview != nil
    }


    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(minimalPreviews ? Color.clear : Color.white.opacity(0.06))

                if let preview {
                    Image(decorative: preview, scale: 2)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(5)
                } else if window.isAppEntry {
                    appEntryMark
                } else if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: SwitcherGridCard.fallbackIconSize,
                               height: SwitcherGridCard.fallbackIconSize)
                        .switcherHiddenAppBadge(window.isAppHidden, size: 22 * PreviewSizing.switcherScale)
                }

                // The name, one line, centered along the bottom of the picture,
                // led by the app's icon so the app needs no second line. The
                // window's state sits in the top corner, away from the name.
                if !minimalPreviews {
                    VStack(spacing: 0) {
                        HStack {
                            if hasStatusBadges {
                                HStack(spacing: 5) {
                                    statusBadges
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                        SwitcherWindowTitlePill(title: window.displayTitle,
                                                icon: showsAppBadge ? window.appIcon : nil,
                                                isSelected: isSelected,
                                                maxTitleWidth: SwitcherGridCard.titleWidth - 40,
                                                scrolls: isHovering)
                    }
                    .padding(8)
                }

                VStack {
                    HStack {
                        Spacer()
                        closeButton
                            .padding(6)
                    }
                    Spacer()
                }
            }
            .frame(width: SwitcherGridCard.thumbnailWidth,
                   height: SwitcherGridCard.thumbnailHeight)
        }
        .padding(SwitcherGridCard.padding)
        .frame(width: SwitcherGridCard.width, height: SwitcherGridCard.height)
        .background(SwitcherSelectionBackdrop(isSelected: isSelected, cornerRadius: 14, kind: .window))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            guard !suppressNextCommit else { return }
            onCommit()
        }
        .onHover { isHovering = $0 }
        .scaleEffect(isSelected ? 1.0 : 0.97)
        .animation(animatesSelection ? .spring(response: 0.25, dampingFraction: 0.8) : nil,
                   value: isSelected)
        .accessibilityLabel(window.spokenLabel(noOpenWindow: l10n.s.switcherNoOpenWindow,
                                               hiddenApp: l10n.s.panelHiddenItem,
                                               otherDesktop: l10n.s.switcherOtherDesktop))
    }

    /// An app with no window has nothing to take a thumbnail of. Saying so
    /// under a larger icon is what separates this card from a capture that did
    /// not arrive, which is exactly what a lone icon in an empty well reads as.
    private var appEntryMark: some View {
        VStack(spacing: 9) {
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84 * PreviewSizing.switcherScale, height: 84 * PreviewSizing.switcherScale)
                    .switcherHiddenAppBadge(window.isAppHidden, size: 22 * PreviewSizing.switcherScale)
            }
            Text(l10n.s.switcherNoOpenWindow)
                .font(.system(size: 11 * PreviewSizing.switcherScale, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statusBadges: some View {
        if window.isMinimized {
            statusBadge(systemName: "minus.rectangle")
        }
        if window.isFullscreen {
            statusBadge(systemName: "arrow.up.left.and.arrow.down.right")
        }
        if window.isOnHiddenSpace {
            statusBadge(systemName: "rectangle.stack")
        }
    }

    private func statusBadge(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.9))
            .frame(width: 22, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.46))
            )
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button {
            suppressNextCommit = true
            onClose()
            DispatchQueue.main.async {
                suppressNextCommit = false
            }
        } label: {
            SwitcherCloseButtonLabel(size: 24)
        }
        .buttonStyle(.plain)
        .opacity(showsCloseButton ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: showsCloseButton)
        .allowsHitTesting(showsCloseButton)
        .help(l10n.s.dockPreviewCloseWindow)
        .accessibilityLabel(l10n.s.dockPreviewCloseWindow)
    }
}

/// Lays out switcher cards in rows of `columns`, centered in the width it is
/// given. Unlike a lazy grid it places every card itself, so when the grid
/// reflows (a window closed, a column dropped) each card animates from its old
/// place to its new one under the change's animation.
struct SwitcherCardGridLayout: Layout {
    var columns: Int
    var cardSize: CGSize
    var spacing: CGFloat

    private var columnCount: Int { max(1, columns) }

    private func gridSize(count: Int) -> CGSize {
        let rows = (count + columnCount - 1) / columnCount
        let width = CGFloat(columnCount) * cardSize.width + CGFloat(columnCount - 1) * spacing
        let height = CGFloat(rows) * cardSize.height + CGFloat(max(rows - 1, 0)) * spacing
        return CGSize(width: width, height: max(height, 0))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = gridSize(count: subviews.count)
        return CGSize(width: max(proposal.width ?? size.width, size.width), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = gridSize(count: subviews.count)
        let originX = bounds.minX + max(0, (bounds.width - size.width) / 2)
        for (index, subview) in subviews.enumerated() {
            let row = index / columnCount
            let column = index % columnCount
            subview.place(at: CGPoint(x: originX + CGFloat(column) * (cardSize.width + spacing),
                                      y: bounds.minY + CGFloat(row) * (cardSize.height + spacing)),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(cardSize))
        }
    }
}
