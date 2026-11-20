// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

// MARK: - Types & Protocols

final class WindowSnappingNavigationState: ObservableObject {
    static let shared = WindowSnappingNavigationState()

    /// The page's resting height, which the island sizes itself to. It
    /// survives closing the panel, so every visit after the first opens the
    /// island straight at its final size.
    ///
    /// Kept in memory on purpose. Writing it to UserDefaults posted
    /// `didChangeNotification`, and the island, the status item and the
    /// permission poller all answer that with a full preference sync: one
    /// height change meant an app-wide resync, and the island's re-sync
    /// landed mid-animation.
    @Published private(set) var contentHeight: CGFloat = 580

    /// Shared so the island can switch modes from its band, outside the
    /// control view itself.
    @Published private(set) var mode: SnapViewMode = .customGrid

    /// Modes whose page has been built. The inactive page is built shortly
    /// after the panel opens rather than with it, so opening lays out one
    /// page, not two.
    @Published private(set) var preparedModes: Set<SnapViewMode> = [.customGrid]

    private var recentRestingPublishes: [TimeInterval] = []
    private var naturalHeight: CGFloat = 0
    private var pageHeights: [SnapViewMode: CGFloat] = [:]
    private var transitioning = false
    private var transitionGeneration = 0
    /// Whether the island's page reported a height during the current
    /// switch. A switch made in the floating HUD reports none, and the last
    /// island height must not then be filed under the new mode.
    private var measuredDuringTransition = false

    /// How long the island's page clip stays open below the new size while
    /// a shrink plays: past both the page's curve and the island's spring.
    private static let shrinkOverflowDuration: TimeInterval = 0.8

    private init() {}

    func prepare(_ modes: Set<SnapViewMode>) {
        let missing = modes.subtracting(preparedModes)
        guard !missing.isEmpty else { return }
        preparedModes.formUnion(missing)
    }

    /// The island resizes once per switch, with its own spring, starting
    /// with the page so the two move together. Its outline masks the page
    /// as it springs; on a shrink the page's own clip is held open below the
    /// new size meanwhile, so the rows slide up under the closing outline
    /// instead of being cut at the final size. Driving the window frame by
    /// frame instead re-laid out the whole island on every frame.
    func select(_ newMode: SnapViewMode, animated: Bool) {
        guard mode != newMode else { return }
        if !preparedModes.contains(newMode) {
            // Build the page first and switch on the next turn of the main
            // loop, once it has been measured and the target height is known.
            prepare([newMode])
            DispatchQueue.main.async { [weak self] in self?.select(newMode, animated: animated) }
            return
        }
        let target = targetHeight(for: newMode)
        transitionGeneration += 1
        let generation = transitionGeneration
        transitioning = animated
        measuredDuringTransition = false
        withAnimation(animated ? SnapMotion.stage : nil) {
            mode = newMode
        }
        guard animated else { return }
        if let target {
            if target < contentHeight {
                NotchService.shared.allowPageClipOverflow(contentHeight - target,
                                                          for: Self.shrinkOverflowDuration)
            }
            publish(target, fromSwitch: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + SnapMotion.stageDuration + 0.03) { [weak self] in
            guard let self, self.transitionGeneration == generation else { return }
            self.transitioning = false
            guard self.measuredDuringTransition else { return }
            // Normally a no-op: the target already matched. Covers a page
            // that had not been measured when the switch began.
            self.publish(Self.rounded(self.naturalHeight), fromSwitch: true)
        }
    }

    /// The panel's natural height on this frame. Mid-switch it is an
    /// intermediate height and only recorded.
    func reportNatural(_ height: CGFloat) {
        guard height > 0 else { return }
        naturalHeight = height
        measuredDuringTransition = true
        guard !transitioning else { return }
        publish(Self.rounded(height))
    }

    func reportPage(_ page: SnapViewMode, height: CGFloat) {
        guard height > 0 else { return }
        pageHeights[page] = height
    }

    /// The resting height in `newMode`, from the same measurements the
    /// resting height in the current mode came from, so the two agree to the
    /// point and the end of a switch never asks for a second resize.
    private func targetHeight(for newMode: SnapViewMode) -> CGFloat? {
        guard naturalHeight > 0, let current = pageHeights[mode], let next = pageHeights[newMode] else { return nil }
        return Self.rounded(naturalHeight - current + next)
    }

    private static func rounded(_ height: CGFloat) -> CGFloat {
        // Whole points, tolerant of layout's floating-point dust, so equal
        // layouts never round to heights a point apart.
        ceil(height - 0.01)
    }

    private func publish(_ height: CGFloat, fromSwitch: Bool = false) {
        guard height > 0, abs(contentHeight - height) >= 1 else { return }
        if !fromSwitch {
            // A resting height that keeps changing by itself is a layout
            // feedback loop, and each change resizes the island, which lays
            // the page out again. Past a handful a second, hold the taller
            // height rather than feed the loop.
            let now = ProcessInfo.processInfo.systemUptime
            recentRestingPublishes = recentRestingPublishes.filter { now - $0 < 1 } + [now]
            if recentRestingPublishes.count > 6, height < contentHeight { return }
        }
        contentHeight = height
    }
}

enum SnapViewMode: String, CaseIterable {
    case customGrid
    case layoutPresets

    var title: String {
        let text = WindowSnappingStrings.current
        switch self {
        case .customGrid: return text.customGrid
        case .layoutPresets: return text.layoutPresets
        }
    }

    /// For the compact island band, where the full title does not fit.
    var shortTitle: String {
        let text = WindowSnappingStrings.current
        switch self {
        case .customGrid: return text.gridShort
        case .layoutPresets: return text.presetsShort
        }
    }
}

/// The island's mode selector, sitting in the band beside the pin button.
/// Its menu always lists full titles; the closed label is short in the
/// compact island and full in the spacious one.
struct WindowSnappingModeMenu: View {
    var compact: Bool

    @ObservedObject private var navigation = WindowSnappingNavigationState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let mode = navigation.mode
        Menu {
            Picker(WindowSnappingStrings.current.modeLabel, selection: Binding(
                get: { navigation.mode },
                set: { navigation.select($0, animated: !reduceMotion) }
            )) {
                ForEach(SnapViewMode.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            // One text run, so the menu label keeps the chevron after the name.
            (Text((compact ? mode.shortTitle : mode.title) + " ")
             + Text(Image(systemName: "chevron.down")).font(.system(size: 8, weight: .bold)))
            .foregroundStyle(Color.white.opacity(0.6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .controlSize(.small)
        .accessibilityLabel(WindowSnappingStrings.current.modeLabel)
        .accessibilityValue(mode.title)
    }
}

enum GridDivision: Int, CaseIterable {
    case halves = 2
    case thirds = 3
    case quarters = 4
    case sixths = 6
}

enum GridOrientation: String {
    case primary   // Cols (2/3/4) or 3×2 (Grid)
    case secondary // Rows (2/3/4) or 2×3 (Grid)
    case square    // 2×2 corners (Quarters only)
}

struct GridCoord: Hashable {
    let col: Int
    let row: Int

    init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }
}

enum QuickAction: String, CaseIterable {
    case maximize
    case maximizeMargin
    case fullScreen
    case center
    case prevDisplay
    case nextDisplay
    case restore

    var title: String {
        let t = WindowSnappingPanelStrings.current
        switch self {
        case .maximize: return t.maximize
        case .maximizeMargin: return t.maximizeMargin
        case .fullScreen: return t.fullScreen
        case .center: return t.centerWindow
        case .prevDisplay: return t.prevDisplay
        case .nextDisplay: return t.nextDisplay
        case .restore: return t.restore
        }
    }

    var symbolName: String {
        switch self {
        case .maximize: return "viewfinder"
        case .maximizeMargin: return "rectangle.inset.filled"
        case .fullScreen: return "square"
        case .center: return "scope"
        case .prevDisplay: return "arrow.left.to.line"
        case .nextDisplay: return "arrow.right.to.line"
        case .restore: return "arrow.uturn.backward"
        }
    }

    var layoutAction: WindowLayoutAction {
        switch self {
        case .maximize: return .maximize
        case .maximizeMargin: return .marginMaximize
        case .fullScreen: return .fullScreen
        case .center: return .center
        case .prevDisplay: return .previousDisplay
        case .nextDisplay: return .nextDisplay
        case .restore: return .restore
        }
    }
}

struct WindowSnappingCallbacks {
    /// Called on hover/drag over a cell, preset pane, or spatial quick action.
    /// Host renders/updates the translucent desktop ghost window; `nil` hides it.
    var onPreview: (NormalizedRect?, String?) -> Void

    /// Called when user clicks/releases a grid span or preset pane.
    /// Host converts NormalizedRect using target NSScreen.visibleFrame and applies AXUIElement frame.
    var onSnap: (NormalizedRect, String) -> Void

    /// Called when a non-grid quick action is triggered.
    var onAction: (QuickAction) -> Void

    /// Called whenever intrinsic height changes (e.g., Custom Grid vs. Layout Presets)
    /// so Dynamic Island or Floating HUD can smoothly animate its container height.
    var onPreferredHeightChange: ((CGFloat) -> Void)?

    /// Called just before the view animates its own height (switching between
    /// Custom Grid and Layout Presets), with the animation's duration. A host
    /// window should follow every intermediate size for that long instead of
    /// running a resize animation of its own, which would lag the content.
    var onLayoutTransition: ((TimeInterval) -> Void)?

    init(
        onPreview: @escaping (NormalizedRect?, String?) -> Void = { _, _ in },
        onSnap: @escaping (NormalizedRect, String) -> Void = { _, _ in },
        onAction: @escaping (QuickAction) -> Void = { _ in },
        onPreferredHeightChange: ((CGFloat) -> Void)? = nil,
        onLayoutTransition: ((TimeInterval) -> Void)? = nil
    ) {
        self.onPreview = onPreview
        self.onSnap = onSnap
        self.onAction = onAction
        self.onPreferredHeightChange = onPreferredHeightChange
        self.onLayoutTransition = onLayoutTransition
    }
}

// MARK: - Grid Resolution & Labels

extension GridDivision {
    func dimensions(orientation: GridOrientation) -> (cols: Int, rows: Int) {
        switch self {
        case .halves:
            return orientation == .secondary ? (1, 2) : (2, 1)
        case .thirds:
            return orientation == .secondary ? (1, 3) : (3, 1)
        case .quarters:
            switch orientation {
            case .square: return (2, 2)
            case .primary: return (4, 1)
            case .secondary: return (1, 4)
            }
        case .sixths:
            return orientation == .secondary ? (2, 3) : (3, 2)
        }
    }

    var title: String {
        let text = WindowSnappingStrings.current
        switch self {
        case .halves: return text.split
        case .thirds: return text.threeWay
        case .quarters: return text.quarters
        case .sixths: return text.grid
        }
    }

    /// The layouts this division offers, in the order the toggle shows them.
    var orientations: [GridOrientation] {
        self == .quarters ? [.square, .primary, .secondary] : [.primary, .secondary]
    }
}

private enum GridResolutionHelper {
    static func spanRect(anchor: GridCoord, current: GridCoord, cols: Int, rows: Int) -> NormalizedRect {
        let minCol = min(anchor.col, current.col)
        let maxCol = max(anchor.col, current.col)
        let minRow = min(anchor.row, current.row)
        let maxRow = max(anchor.row, current.row)
        return NormalizedRect(
            x: CGFloat(minCol) / CGFloat(cols),
            y: CGFloat(minRow) / CGFloat(rows),
            width: CGFloat(maxCol - minCol + 1) / CGFloat(cols),
            height: CGFloat(maxRow - minRow + 1) / CGFloat(rows)
        )
    }

    static func zoneLabel(minCol: Int, maxCol: Int, minRow: Int, maxRow: Int, cols: Int, rows: Int) -> String {
        let t = WindowSnappingPanelStrings.current
        let isFullCol = minCol == 0 && maxCol == cols - 1
        let isFullRow = minRow == 0 && maxRow == rows - 1

        if isFullCol && isFullRow {
            return t.maximize
        }

        // Single row division (Cols orientation)
        if rows == 1 {
            if cols == 2 {
                return minCol == 0 ? t.half(t.left) : t.half(t.right)
            } else if cols == 3 {
                if minCol == maxCol {
                    if minCol == 0 { return t.part(t.left, "1/3") }
                    if minCol == 1 { return t.part(t.center, "1/3") }
                    return t.part(t.right, "1/3")
                } else if minCol == 0 && maxCol == 1 {
                    return t.part(t.left, "2/3")
                } else if minCol == 1 && maxCol == 2 {
                    return t.part(t.right, "2/3")
                }
            } else if cols == 4 {
                if minCol == maxCol {
                    if minCol == 0 { return t.part(t.left, "1/4") }
                    if minCol == 1 { return t.part(t.centerLeft, "1/4") }
                    if minCol == 2 { return t.part(t.centerRight, "1/4") }
                    return t.part(t.right, "1/4")
                } else if minCol == 0 && maxCol == 1 {
                    return t.half(t.left)
                } else if minCol == 1 && maxCol == 2 {
                    return t.half(t.center)
                } else if minCol == 2 && maxCol == 3 {
                    return t.half(t.right)
                } else if minCol == 0 && maxCol == 2 {
                    return t.part(t.left, "3/4")
                } else if minCol == 1 && maxCol == 3 {
                    return t.part(t.right, "3/4")
                }
            }
        }

        // Single column division (Rows orientation)
        if cols == 1 {
            if rows == 2 {
                return minRow == 0 ? t.half(t.top) : t.half(t.bottom)
            } else if rows == 3 {
                if minRow == maxRow {
                    if minRow == 0 { return t.part(t.top, "1/3") }
                    if minRow == 1 { return t.part(t.middle, "1/3") }
                    return t.part(t.bottom, "1/3")
                } else if minRow == 0 && maxRow == 1 {
                    return t.part(t.top, "2/3")
                } else if minRow == 1 && maxRow == 2 {
                    return t.part(t.bottom, "2/3")
                }
            } else if rows == 4 {
                if minRow == maxRow {
                    if minRow == 0 { return t.part(t.top, "1/4") }
                    if minRow == 1 { return t.part(t.upperCenter, "1/4") }
                    if minRow == 2 { return t.part(t.lowerCenter, "1/4") }
                    return t.part(t.bottom, "1/4")
                } else if minRow == 0 && maxRow == 1 {
                    return t.half(t.top)
                } else if minRow == 1 && maxRow == 2 {
                    return t.half(t.center)
                } else if minRow == 2 && maxRow == 3 {
                    return t.half(t.bottom)
                }
            }
        }

        // Quarters 2×2
        if cols == 2 && rows == 2 {
            if minRow == maxRow && isFullCol { return minRow == 0 ? t.half(t.top) : t.half(t.bottom) }
            if minCol == maxCol && isFullRow { return minCol == 0 ? t.half(t.left) : t.half(t.right) }
            if minCol == maxCol && minRow == maxRow {
                return t.corner(row: minRow == 0 ? t.top : t.bottom, col: minCol == 0 ? t.left : t.right)
            }
        }

        // Sixths 3×2
        if cols == 3 && rows == 2 {
            if isFullRow {
                if minCol == maxCol {
                    return minCol == 0 ? t.part(t.left, "1/3") : (minCol == 1 ? t.part(t.center, "1/3") : t.part(t.right, "1/3"))
                } else if minCol == 0 && maxCol == 1 {
                    return t.part(t.left, "2/3")
                } else if minCol == 1 && maxCol == 2 {
                    return t.part(t.right, "2/3")
                }
            }
            if isFullCol {
                return minRow == 0 ? t.half(t.top) : t.half(t.bottom)
            }
            if minCol == maxCol && minRow == maxRow {
                let colStr = minCol == 0 ? t.left : (minCol == 1 ? t.center : t.right)
                let rowStr = minRow == 0 ? t.top : t.bottom
                return t.part(t.corner(row: rowStr, col: colStr), "1/6")
            }
        }

        // Sixths 2×3
        if cols == 2 && rows == 3 {
            if isFullCol {
                if minRow == maxRow {
                    return minRow == 0 ? t.part(t.top, "1/3") : (minRow == 1 ? t.part(t.middle, "1/3") : t.part(t.bottom, "1/3"))
                } else if minRow == 0 && maxRow == 1 {
                    return t.part(t.top, "2/3")
                } else if minRow == 1 && maxRow == 2 {
                    return t.part(t.bottom, "2/3")
                }
            }
            if isFullRow {
                return minCol == 0 ? t.half(t.left) : t.half(t.right)
            }
            if minCol == maxCol && minRow == maxRow {
                let colStr = minCol == 0 ? t.left : t.right
                let rowStr = minRow == 0 ? t.top : (minRow == 1 ? t.middle : t.bottom)
                return t.part(t.corner(row: rowStr, col: colStr), "1/6")
            }
        }

        let widthFraction = "\(maxCol - minCol + 1)/\(cols)"
        let heightFraction = "\(maxRow - minRow + 1)/\(rows)"
        return t.zone(widthFraction, heightFraction)
    }
}

// MARK: - Layout Presets Definition

struct PresetPane: Identifiable {
    let id: String
    let rect: NormalizedRect
    let label: String
}

struct LayoutPresetModel: Identifiable {
    let id: String
    let name: String
    let panes: [PresetPane]

    /// Built on each read so names and pane labels follow the app language.
    static var allPresets: [LayoutPresetModel] {
        let t = WindowSnappingPanelStrings.current
        return [
            LayoutPresetModel(
                id: "50-50",
                name: "50 / 50",
                panes: [
                    PresetPane(id: "50-50-left", rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1), label: t.half(t.left)),
                    PresetPane(id: "50-50-right", rect: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1), label: t.half(t.right))
                ]
            ),
            LayoutPresetModel(
                id: "3-cols",
                name: t.threeColumns,
                panes: [
                    PresetPane(id: "3-cols-left", rect: NormalizedRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1), label: t.part(t.left, "1/3")),
                    PresetPane(id: "3-cols-center", rect: NormalizedRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1), label: t.part(t.center, "1/3")),
                    PresetPane(id: "3-cols-right", rect: NormalizedRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1), label: t.part(t.right, "1/3"))
                ]
            ),
            LayoutPresetModel(
                id: "70-30",
                name: "70 / 30",
                panes: [
                    PresetPane(id: "70-30-left", rect: NormalizedRect(x: 0, y: 0, width: 0.7, height: 1), label: t.primary(t.left)),
                    PresetPane(id: "70-30-right", rect: NormalizedRect(x: 0.7, y: 0, width: 0.3, height: 1), label: t.side(t.right))
                ]
            ),
            LayoutPresetModel(
                id: "30-70",
                name: "30 / 70",
                panes: [
                    PresetPane(id: "30-70-left", rect: NormalizedRect(x: 0, y: 0, width: 0.3, height: 1), label: t.side(t.left)),
                    PresetPane(id: "30-70-right", rect: NormalizedRect(x: 0.3, y: 0, width: 0.7, height: 1), label: t.primary(t.right))
                ]
            ),
            LayoutPresetModel(
                id: "2x2",
                name: t.quarters,
                panes: [
                    PresetPane(id: "2x2-tl", rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5), label: t.corner(row: t.top, col: t.left)),
                    PresetPane(id: "2x2-tr", rect: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5), label: t.corner(row: t.top, col: t.right)),
                    PresetPane(id: "2x2-bl", rect: NormalizedRect(x: 0, y: 0.5, width: 0.5, height: 0.5), label: t.corner(row: t.bottom, col: t.left)),
                    PresetPane(id: "2x2-br", rect: NormalizedRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5), label: t.corner(row: t.bottom, col: t.right))
                ]
            ),
            LayoutPresetModel(
                id: "main-stack",
                name: t.mainStack,
                panes: [
                    PresetPane(id: "main-stack-main", rect: NormalizedRect(x: 0, y: 0, width: 2.0 / 3.0, height: 1), label: t.primary(t.left)),
                    PresetPane(id: "main-stack-top", rect: NormalizedRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 0.5), label: t.stack(t.corner(row: t.top, col: t.right))),
                    PresetPane(id: "main-stack-bottom", rect: NormalizedRect(x: 2.0 / 3.0, y: 0.5, width: 1.0 / 3.0, height: 0.5), label: t.stack(t.corner(row: t.bottom, col: t.right)))
                ]
            ),
        ]
    }
}

// MARK: - Palette

/// One palette for both appearances: neutrals are the label colour at an
/// opacity, so they read as light-on-dark in the dark HUD and island and as
/// dark-on-light in the light HUD. Only the selection accent is a fixed hue.
private enum SnapTone {
    static let accent = Color(red: 10/255, green: 132/255, blue: 255/255)
    static let accentStroke = Color(red: 64/255, green: 156/255, blue: 255/255)

    static func ink(_ opacity: Double) -> Color { Color.primary.opacity(opacity) }
}

private enum SnapMotion {
    /// Mode switches resize the whole page. One curve, with no overshoot,
    /// drives the stage height, the rows below it and the host window.
    static let stageDuration: TimeInterval = 0.34
    static let stage = Animation.timingCurve(0.32, 0.72, 0, 1, duration: stageDuration)
}

// MARK: - Main Control View

struct WindowSnappingControlView: View {
    var callbacks: WindowSnappingCallbacks
    var canRestore: Bool

    @Namespace private var switcherNamespace

    @ObservedObject private var navigation = WindowSnappingNavigationState.shared
    private var viewMode: SnapViewMode { navigation.mode }
    @State private var division: GridDivision = .halves
    @State private var orientation: GridOrientation = .primary

    @State private var hoveredCoord: GridCoord? = nil
    @State private var dragAnchor: GridCoord? = nil
    @State private var dragCurrent: GridCoord? = nil
    @State private var isDragging: Bool = false

    @State private var hoveredPaneId: String? = nil
    @State private var toastText: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    @State private var statusText: String = WindowSnappingPanelStrings.current.gridHint


    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // State, not a stored constant: the view struct is rebuilt on every
    // parent update, which would otherwise reset a gesture mid-flight.
    @State private var scrollStepper = ScrollDivisionStepper()

    /// Outer width of the page. The floating HUD uses the default; the
    /// island passes its own width so the page fills it edge to edge.
    var layoutWidth: CGFloat
    var horizontalInset: CGFloat
    var verticalInset: CGFloat
    /// The island hosts the mode selector in its band instead.
    var showsModeSwitcher: Bool
    /// Whether this page's height is the one the island sizes itself to.
    /// The floating HUD measures its own page and must not overwrite it.
    var drivesIslandHeight: Bool

    private var contentWidth: CGFloat { max(300, layoutWidth - horizontalInset * 2) }

    init(
        callbacks: WindowSnappingCallbacks = WindowSnappingCallbacks(),
        canRestore: Bool = true,
        layoutWidth: CGFloat = 376,
        horizontalInset: CGFloat = 14,
        verticalInset: CGFloat = 14,
        showsModeSwitcher: Bool = true,
        drivesIslandHeight: Bool = false
    ) {
        self.callbacks = callbacks
        self.canRestore = canRestore
        self.layoutWidth = layoutWidth
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        self.showsModeSwitcher = showsModeSwitcher
        self.drivesIslandHeight = drivesIslandHeight
    }

    public var body: some View {
        VStack(spacing: 12) {
            if showsModeSwitcher {
                viewSwitcher
            }

            modeStage

            // The help strip and quick actions move as one rigid block with
            // the stage's animated bottom edge; nothing below it animates on
            // a curve of its own.
            VStack(spacing: 12) {
                statusStrip
                quickActionsSection
            }
        }
        .frame(width: contentWidth)
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
        .frame(width: contentWidth + horizontalInset * 2)
        .onChange(of: navigation.mode) { _, _ in resetInteractions() }
        // Natural height whatever the host proposes, so the island's frame
        // can never feed back into the height it is sized from.
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            // Intermediate during a mode switch: the stage layout re-runs
            // on every frame of its animation.
            if drivesIslandHeight { navigation.reportNatural(height) }
            callbacks.onPreferredHeightChange?(ceil(height))
        }
        .onAppear {
            // The other page is built once opening has settled, not with it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                navigation.prepare(Set(SnapViewMode.allCases))
            }
        }
    }

    // MARK: - Mode Stage

    /// Both pages stay in the hierarchy. The stage interpolates its height
    /// between them and clips, so the outgoing page fades inside a shrinking
    /// window and never overlaps the rows below it.
    private var modeStage: some View {
        SnapModeStageLayout(progress: viewMode == .customGrid ? 0 : 1) {
            stagePage(.customGrid) { customGridBody }
            stagePage(.layoutPresets) { layoutPresetsBody }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    /// A page that is not built yet holds its slot with no height, so the
    /// stage layout always sees the grid first and the presets second.
    @ViewBuilder
    private func stagePage<Page: View>(_ mode: SnapViewMode, @ViewBuilder _ page: () -> Page) -> some View {
        if navigation.preparedModes.contains(mode) || viewMode == mode {
            page()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    if drivesIslandHeight { navigation.reportPage(mode, height: height) }
                }
                .modifier(SnapStagePage(isActive: viewMode == mode, reduceMotion: reduceMotion))
        } else {
            Color.clear.frame(height: 0)
        }
    }

    private func switchMode(to mode: SnapViewMode) {
        guard viewMode != mode else { return }
        NSCursor.arrow.set()
        if !reduceMotion {
            callbacks.onLayoutTransition?(SnapMotion.stageDuration + 0.06)
        }
        navigation.select(mode, animated: !reduceMotion)
    }

    // MARK: - View Switcher

    private var viewSwitcher: some View {
        HStack(spacing: 0) {
            switcherButton(title: SnapViewMode.customGrid.title, mode: .customGrid)
            switcherButton(title: SnapViewMode.layoutPresets.title, mode: .layoutPresets)
        }
        .padding(2.5)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(SnapTone.ink(0.06))
        )
    }

    private func switcherButton(title: String, mode: SnapViewMode) -> some View {
        let isSelected = viewMode == mode
        return Button {
            switchMode(to: mode)
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .fill(SnapTone.ink(0.14))
                        .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
                        .matchedGeometryEffect(id: "switcherPill", in: switcherNamespace)
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isSelected ? SnapTone.ink(1) : SnapTone.ink(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Grid Mode

    private var customGridBody: some View {
        VStack(spacing: 11) {
            divisionAndAxisRow
            miniScreenCanvas
        }
    }

    /// Labels are never truncated. Where a language's words are too wide
    /// for the panel at the usual size, the row steps its type down instead
    /// of overflowing.
    private var divisionAndAxisRow: some View {
        ViewThatFits(in: .horizontal) {
            divisionAndAxisRow(fontSize: 11.5)
            divisionAndAxisRow(fontSize: 10.5)
            divisionAndAxisRow(fontSize: 9.5)
        }
        .frame(height: 28)
    }

    private func divisionAndAxisRow(fontSize: CGFloat) -> some View {
        HStack(spacing: 8) {
            divisionSelector(fontSize: fontSize)
                .overlay(
                    ScrollWheelPassthroughRepresentable(isInteractive: viewMode == .customGrid) { event in
                        handleScroll(event)
                    }
                )

            axisToggle(fontSize: fontSize)
        }
    }

    private func divisionSelector(fontSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(GridDivision.allCases, id: \.self) { div in
                divisionButton(title: div.title, div: div, fontSize: fontSize)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SnapTone.ink(0.06))
        )
    }

    private func divisionButton(title: String, div: GridDivision, fontSize: CGFloat) -> some View {
        let isSelected = division == div
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                setDivision(div)
            }
        } label: {
            // Never truncated: each segment is at least its label plus a
            // little air, and segments share whatever room is left over.
            Text(title)
                .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : SnapTone.ink(0.6))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // A plain button only hits where it draws; the whole
                // segment, not just its text, takes the click.
                .contentShape(Rectangle())
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(SnapTone.accent)
                                .shadow(color: SnapTone.accent.opacity(0.35), radius: 2, x: 0, y: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func axisToggle(fontSize: CGFloat) -> some View {
        let options = division.orientations
        // Quarters adds 2×2 on the left. Segments get a little narrower
        // rather than squeezing the division selector beside them.
        let segmentWidth: CGFloat = options.count > 2 ? 38 : 42

        return HStack(spacing: 0) {
            ForEach(options, id: \.self) { orient in
                axisButton(title: axisTitle(orient), orient: orient, fontSize: fontSize)
                    .frame(minWidth: segmentWidth)
            }
        }
        .padding(2)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SnapTone.ink(0.06))
        )
    }

    private func axisTitle(_ orient: GridOrientation) -> String {
        switch orient {
        case .square: return "2×2"
        case .primary: return division == .sixths ? "3×2" : WindowSnappingStrings.current.cols
        case .secondary: return division == .sixths ? "2×3" : WindowSnappingStrings.current.rows
        }
    }

    private func axisButton(title: String, orient: GridOrientation, fontSize: CGFloat) -> some View {
        let isSelected = orientation == orient
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                orientation = orient
                showToast(for: division, orientation: orient)
                updatePreviewOnGridChange()
            }
        } label: {
            Text(title)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(isSelected ? SnapTone.ink(1) : SnapTone.ink(0.6))
                .lineLimit(1)
                // At least the segment's usual width, wider for a longer
                // translation, never truncated.
                .fixedSize()
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(SnapTone.ink(0.14))
                                .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 16:10 Interactive Mini-Screen

    private var miniScreenCanvas: some View {
        let dims = division.dimensions(orientation: orientation)
        // 16:10 at the HUD's width; on a wider island the screen widens but
        // stops growing taller, so the page does not run away vertically.
        let canvasW: CGFloat = contentWidth
        let canvasH: CGFloat = min(contentWidth * 10 / 16, 250)

        return ZStack {
            // Silhouette container: a neutral plate with a faint blue-violet
            // wash that reads as a screen in either appearance.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SnapTone.ink(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.40, blue: 0.95).opacity(0.10),
                                    Color(red: 0.55, green: 0.30, blue: 0.90).opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(SnapTone.ink(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                // Top silhouette titlebar
                HStack(spacing: 6) {
                    Circle()
                        .fill(SnapTone.ink(0.35))
                        .frame(width: 5, height: 5)
                    Capsule()
                        .fill(SnapTone.ink(0.20))
                        .frame(width: 26, height: 4.5)
                    Spacer()
                    Capsule()
                        .fill(SnapTone.ink(0.20))
                        .frame(width: 14, height: 3.5)
                    Capsule()
                        .fill(SnapTone.ink(0.20))
                        .frame(width: 14, height: 3.5)
                }
                .padding(.horizontal, 10)
                .frame(height: 18)
                .padding(.top, 4)

                // Grid cards area
                ZStack {
                    VStack(spacing: 5) {
                        ForEach(0..<dims.rows, id: \.self) { r in
                            HStack(spacing: 5) {
                                ForEach(0..<dims.cols, id: \.self) { c in
                                    gridCellCard(col: c, row: r, dims: dims)
                                }
                            }
                        }
                    }

                    // Native pointer & scroll event overlay with crosshair cursor
                    MiniScreenCanvasRepresentable(
                        cols: dims.cols,
                        rows: dims.rows,
                        isInteractive: viewMode == .customGrid,
                        onHover: { coord in
                            guard !isDragging else { return }
                            hoveredCoord = coord
                            let rect = GridResolutionHelper.spanRect(anchor: coord, current: coord, cols: dims.cols, rows: dims.rows)
                            let label = GridResolutionHelper.zoneLabel(minCol: coord.col, maxCol: coord.col, minRow: coord.row, maxRow: coord.row, cols: dims.cols, rows: dims.rows)
                            callbacks.onPreview(rect, label)
                            statusText = WindowSnappingPanelStrings.current.clickToSnap(label)
                        },
                        onMouseDown: { coord in
                            dragAnchor = coord
                            dragCurrent = coord
                            isDragging = true
                            hoveredCoord = coord
                            let rect = GridResolutionHelper.spanRect(anchor: coord, current: coord, cols: dims.cols, rows: dims.rows)
                            let label = GridResolutionHelper.zoneLabel(minCol: coord.col, maxCol: coord.col, minRow: coord.row, maxRow: coord.row, cols: dims.cols, rows: dims.rows)
                            callbacks.onPreview(rect, label)
                            statusText = WindowSnappingPanelStrings.current.releaseToSnap(label)
                        },
                        onMouseDragged: { coord in
                            guard isDragging, let anchor = dragAnchor else { return }
                            hoveredCoord = coord
                            if coord != dragCurrent {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                    dragCurrent = coord
                                }
                                let rect = GridResolutionHelper.spanRect(anchor: anchor, current: coord, cols: dims.cols, rows: dims.rows)
                                let minC = min(anchor.col, coord.col)
                                let maxC = max(anchor.col, coord.col)
                                let minR = min(anchor.row, coord.row)
                                let maxR = max(anchor.row, coord.row)
                                let label = GridResolutionHelper.zoneLabel(minCol: minC, maxCol: maxC, minRow: minR, maxRow: maxR, cols: dims.cols, rows: dims.rows)
                                callbacks.onPreview(rect, label)
                                statusText = WindowSnappingPanelStrings.current.releaseToSnap(label)
                            }
                        },
                        onMouseUp: { releaseCoord in
                            if isDragging, let anchor = dragAnchor {
                                let rect = GridResolutionHelper.spanRect(anchor: anchor, current: releaseCoord, cols: dims.cols, rows: dims.rows)
                                let minC = min(anchor.col, releaseCoord.col)
                                let maxC = max(anchor.col, releaseCoord.col)
                                let minR = min(anchor.row, releaseCoord.row)
                                let maxR = max(anchor.row, releaseCoord.row)
                                let label = GridResolutionHelper.zoneLabel(minCol: minC, maxCol: maxC, minRow: minR, maxRow: maxR, cols: dims.cols, rows: dims.rows)
                                callbacks.onSnap(rect, label)
                            }
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                isDragging = false
                                dragAnchor = nil
                                dragCurrent = nil
                                hoveredCoord = releaseCoord
                            }
                            callbacks.onPreview(nil, nil)
                            let singleLabel = GridResolutionHelper.zoneLabel(
                                minCol: releaseCoord.col, maxCol: releaseCoord.col,
                                minRow: releaseCoord.row, maxRow: releaseCoord.row,
                                cols: dims.cols, rows: dims.rows
                            )
                            statusText = WindowSnappingPanelStrings.current.clickToSnap(singleLabel)
                        },
                        onMouseExited: {
                            guard !isDragging else { return }
                            hoveredCoord = nil
                            callbacks.onPreview(nil, nil)
                            statusText = WindowSnappingPanelStrings.current.gridHint
                        },
                        onScroll: { event in
                            handleScroll(event)
                        }
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom silhouette dock pill
                Capsule()
                    .fill(SnapTone.ink(0.28))
                    .frame(width: 44, height: 3.5)
                    .padding(.bottom, 6)
            }

            // Centered transient toast
            if let toast = toastText {
                Text(toast)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color(white: 0.98))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.78))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 3)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(width: canvasW, height: canvasH)
    }

    private func gridCellCard(col: Int, row: Int, dims: (cols: Int, rows: Int)) -> some View {
        let isSelected = isCellSelected(col: col, row: row)
        let label = cellLabel(col: col, row: row, dims: dims)

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isSelected
                        ? SnapTone.accent.opacity(0.28)
                        : SnapTone.ink(0.06)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? SnapTone.accentStroke
                                : SnapTone.ink(0.10),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )

            Text(label)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? SnapTone.ink(1) : SnapTone.ink(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .padding(.horizontal, 4)
        }
        .scaleEffect(isSelected ? 1.0 : 0.93)
        .shadow(
            color: isSelected ? SnapTone.accent.opacity(0.40) : .clear,
            radius: isSelected ? 8 : 0,
            x: 0,
            y: 2
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isSelected)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cellLabel(col: Int, row: Int, dims: (cols: Int, rows: Int)) -> String {
        let t = WindowSnappingPanelStrings.current
        if dims.rows == 1 {
            switch dims.cols {
            case 2:
                return col == 0 ? t.part(t.left, "1/2") : t.part(t.right, "1/2")
            case 3:
                if col == 0 { return t.part(t.left, "1/3") }
                if col == 1 { return t.part(t.center, "1/3") }
                return t.part(t.right, "1/3")
            case 4:
                if col == 0 { return t.part(t.left, "1/4") }
                if col == 1 { return t.part(t.col, "2/4") }
                if col == 2 { return t.part(t.col, "3/4") }
                return t.part(t.right, "1/4")
            default:
                return "\(t.col) \(col + 1)"
            }
        }
        if dims.cols == 1 {
            switch dims.rows {
            case 2:
                return row == 0 ? t.part(t.top, "1/2") : t.part(t.bottom, "1/2")
            case 3:
                if row == 0 { return t.part(t.top, "1/3") }
                if row == 1 { return t.part(t.center, "1/3") }
                return t.part(t.bottom, "1/3")
            case 4:
                if row == 0 { return t.part(t.top, "1/4") }
                if row == 1 { return t.part(t.row, "2/4") }
                if row == 2 { return t.part(t.row, "3/4") }
                return t.part(t.bottom, "1/4")
            default:
                return "\(t.row) \(row + 1)"
            }
        }
        if dims.cols == 2 && dims.rows == 2 {
            return t.corner(row: row == 0 ? t.top : t.bottom, col: col == 0 ? t.left : t.right)
        }
        if dims.cols == 3 && dims.rows == 2 {
            let rowPrefix = row == 0 ? t.top : t.bottom
            let colName: String
            switch col {
            case 0: colName = t.left
            case 1: colName = t.center
            default: colName = t.right
            }
            return t.corner(row: rowPrefix, col: colName)
        }
        if dims.cols == 2 && dims.rows == 3 {
            let rowName: String
            switch row {
            case 0: rowName = t.top
            case 1: rowName = t.middleShort
            default: rowName = t.bottomShort
            }
            let colName = col == 0 ? t.left : t.right
            return t.corner(row: rowName, col: colName)
        }
        return "\(col + 1),\(row + 1)"
    }

    private func isCellSelected(col: Int, row: Int) -> Bool {
        if isDragging, let anchor = dragAnchor, let current = dragCurrent {
            let minC = min(anchor.col, current.col)
            let maxC = max(anchor.col, current.col)
            let minR = min(anchor.row, current.row)
            let maxR = max(anchor.row, current.row)
            return col >= minC && col <= maxC && row >= minR && row <= maxR
        } else if let hovered = hoveredCoord {
            return hovered.col == col && hovered.row == row
        }
        return false
    }

    /// Halves is the first stop and Sixths the last: scrolling past either
    /// end does nothing rather than wrapping around.
    private func handleScroll(_ event: NSEvent) {
        guard let step = scrollStepper.step(for: event) else { return }
        let divisions = GridDivision.allCases
        guard let idx = divisions.firstIndex(of: division) else { return }
        let nextIdx = idx + step
        guard divisions.indices.contains(nextIdx) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            setDivision(divisions[nextIdx])
        }
    }

    private func setDivision(_ newDiv: GridDivision) {
        division = newDiv
        if !newDiv.orientations.contains(orientation) { orientation = .primary }
        showToast(for: newDiv, orientation: orientation)
        updatePreviewOnGridChange()
    }

    private func showToast(for div: GridDivision, orientation: GridOrientation) {
        let divName = div.title

        let orientName: String
        switch orientation {
        case .square: orientName = WindowSnappingStrings.current.corners
        case .primary: orientName = div == .sixths ? "3×2" : WindowSnappingStrings.current.columns
        case .secondary: orientName = div == .sixths ? "2×3" : WindowSnappingStrings.current.rowsLong
        }

        toastText = "\(divName) · \(orientName)"
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) {
                    toastText = nil
                }
            }
        }
    }

    private func updatePreviewOnGridChange() {
        // A drag started on the old grid would span cells the new one does
        // not have; it ends here and the next press starts a fresh one.
        if isDragging || dragAnchor != nil {
            dragAnchor = nil
            dragCurrent = nil
            isDragging = false
        }
        if let hovered = hoveredCoord {
            let dims = division.dimensions(orientation: orientation)
            let clampedCol = min(hovered.col, dims.cols - 1)
            let clampedRow = min(hovered.row, dims.rows - 1)
            let newCoord = GridCoord(col: clampedCol, row: clampedRow)
            hoveredCoord = newCoord
            let rect = GridResolutionHelper.spanRect(anchor: newCoord, current: newCoord, cols: dims.cols, rows: dims.rows)
            let label = GridResolutionHelper.zoneLabel(minCol: clampedCol, maxCol: clampedCol, minRow: clampedRow, maxRow: clampedRow, cols: dims.cols, rows: dims.rows)
            callbacks.onPreview(rect, label)
            statusText = WindowSnappingPanelStrings.current.clickToSnap(label)
        }
    }

    // MARK: - Layout Presets Mode

    private var layoutPresetsBody: some View {
        let presets = LayoutPresetModel.allPresets
        let columnCount = contentWidth >= 500 ? 3 : 2
        let thumbWidth = floor((contentWidth - 12 * CGFloat(columnCount - 1)) / CGFloat(columnCount))
        let thumbHeight = min(round(thumbWidth * 96 / 168), 110)
        let columns = Array(repeating: GridItem(.fixed(thumbWidth), spacing: 12), count: columnCount)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(presets) { preset in
                VStack(spacing: 5) {
                    PresetThumbnailRepresentable(
                        preset: preset,
                        hoveredPaneId: hoveredPaneId,
                        isInteractive: viewMode == .layoutPresets,
                        onHover: { pane in
                            if let pane {
                                hoveredPaneId = pane.id
                                callbacks.onPreview(pane.rect, pane.label)
                                statusText = WindowSnappingPanelStrings.current.clickToSnap(pane.label)
                            } else {
                                if let currentId = hoveredPaneId, preset.panes.contains(where: { $0.id == currentId }) {
                                    hoveredPaneId = nil
                                    callbacks.onPreview(nil, nil)
                                    statusText = WindowSnappingPanelStrings.current.presetsHint
                                }
                            }
                        },
                        onSnap: { pane in
                            callbacks.onSnap(pane.rect, pane.label)
                        }
                    )
                    .frame(width: thumbWidth, height: thumbHeight)

                    Text(preset.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SnapTone.ink(0.6))
                }
            }
        }
        .frame(width: contentWidth)
    }

    // MARK: - Status Strip

    private var isHoveringOrActive: Bool {
        if viewMode == .customGrid {
            return hoveredCoord != nil || isDragging
        } else {
            return hoveredPaneId != nil
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 6) {
            if isHoveringOrActive {
                Circle()
                    .fill(SnapTone.accent)
                    .frame(width: 6, height: 6)
            }
            Text(statusText)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isHoveringOrActive ? SnapTone.ink(0.92) : SnapTone.ink(0.6))
                .lineLimit(1)
        }
        // Hover updates swap the text in place. Only its content opts out of
        // animation; the strip itself still travels with the stage, text and
        // plate together.
        .animation(nil, value: statusText)
        .animation(nil, value: isHoveringOrActive)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(SnapTone.ink(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(SnapTone.ink(0.07), lineWidth: 1)
                )
        )
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WindowSnappingPanelStrings.current.quickActions)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.63)
                .foregroundStyle(SnapTone.ink(0.5))

            // Row 1
            HStack(spacing: 8) {
                quickActionButton(
                    title: QuickAction.maximize.title,
                    symbol: "viewfinder",
                    action: .maximize,
                    previewRect: NormalizedRect(x: 0, y: 0, width: 1, height: 1)
                )

                quickActionButton(
                    title: QuickAction.maximizeMargin.title,
                    symbol: "rectangle.inset.filled",
                    action: .maximizeMargin,
                    previewRect: NormalizedRect(x: 0.03, y: 0.04, width: 0.94, height: 0.92)
                )
            }

            // Row 2
            HStack(spacing: 8) {
                quickActionButton(
                    title: QuickAction.fullScreen.title,
                    symbol: "square",
                    action: .fullScreen,
                    previewRect: nil
                )

                quickActionButton(
                    title: QuickAction.center.title,
                    symbol: "scope",
                    action: .center,
                    previewRect: NormalizedRect(x: 0.175, y: 0.15, width: 0.65, height: 0.70)
                )
            }

            // Row 3
            HStack(spacing: 8) {
                // Prev Display
                Button {
                    callbacks.onAction(.prevDisplay)
                } label: {
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 10.5, weight: .semibold))
                            Image(systemName: "display")
                                .font(.system(size: 12, weight: .regular))
                        }
                        Text(QuickAction.prevDisplay.title)
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(SnapTone.ink(0.92))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(SnapActionHostButtonStyle())

                // Next Display
                Button {
                    callbacks.onAction(.nextDisplay)
                } label: {
                    HStack(spacing: 6) {
                        Text(QuickAction.nextDisplay.title)
                            .font(.system(size: 12.5, weight: .medium))
                        HStack(spacing: 3) {
                            Image(systemName: "display")
                                .font(.system(size: 12, weight: .regular))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                    }
                    .foregroundStyle(SnapTone.ink(0.92))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(SnapActionHostButtonStyle())
            }

            // Restore Previous Size
            Button {
                callbacks.onAction(.restore)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11.5, weight: .medium))
                    Text(QuickAction.restore.title)
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(canRestore ? SnapTone.ink(0.92) : SnapTone.ink(0.35))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(SnapActionHostButtonStyle())
            .disabled(!canRestore)
            // Becoming available (or not) after a snap eases in rather than
            // flipping, label and plate together.
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: canRestore)
        }
    }

    private func quickActionButton(
        title: String,
        symbol: String,
        action: QuickAction,
        previewRect: NormalizedRect?
    ) -> some View {
        Button {
            callbacks.onAction(action)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(SnapTone.ink(0.92))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(SnapActionHostButtonStyle())
        .onHover { isHover in
            if isHover, let previewRect {
                callbacks.onPreview(previewRect, title)
            } else if !isHover {
                callbacks.onPreview(nil, nil)
            }
        }
    }

    private func resetInteractions() {
        hoveredCoord = nil
        dragAnchor = nil
        dragCurrent = nil
        isDragging = false
        hoveredPaneId = nil
        callbacks.onPreview(nil, nil)
        statusText = viewMode == .customGrid
            ? WindowSnappingPanelStrings.current.gridHint
            : WindowSnappingPanelStrings.current.presetsHint
    }
}

// MARK: - Mode Stage Layout

/// Lays both mode pages at their natural size, pinned to the top, and reports
/// a height interpolated between them. `progress` is animatable, so layout
/// re-runs on every frame of a switch: the rows below the stage and the host
/// window read real intermediate heights instead of jumping to the target
/// while the rendered content catches up.
private struct SnapModeStageLayout: Layout {
    /// 0 shows the first subview's height, 1 the second's.
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
        guard let first = sizes.first else { return .zero }
        let second = sizes.count > 1 ? sizes[1] : first
        let t = max(0, min(1, progress))
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? max(first.width, second.width)
        return CGSize(width: width, height: first.height + (second.height - first.height) * t)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                          proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }
}

/// The outgoing page fades quickly while the stage starts to move; the
/// incoming page fades in a beat later and settles from a slight lift, so the
/// two never read as stacked on top of each other.
private struct SnapStagePage: ViewModifier {
    let isActive: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(y: isActive || reduceMotion ? 0 : -6)
            .animation(animation, value: isActive)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }

    private var animation: Animation? {
        if reduceMotion { return .easeInOut(duration: 0.15) }
        return isActive
            ? .easeOut(duration: 0.24).delay(0.1)
            : .easeOut(duration: 0.12)
    }
}

// MARK: - Action Button Component

struct SnapActionHostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SnapActionButtonContent(configuration: configuration)
    }

    private struct SnapActionButtonContent: View {
        let configuration: Configuration
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            !isEnabled
                                ? SnapTone.ink(0.035)
                                : configuration.isPressed
                                ? SnapTone.ink(0.18)
                                : (isHovered ? SnapTone.ink(0.13) : SnapTone.ink(0.075))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(SnapTone.ink(isEnabled ? 0.07 : 0.04), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .onHover { isHovered = $0 }
        }
    }
}

// MARK: - Layout Presets AppKit Card

private struct PresetThumbnailRepresentable: NSViewRepresentable {
    let preset: LayoutPresetModel
    var hoveredPaneId: String?
    var isInteractive: Bool
    var onHover: (PresetPane?) -> Void
    var onSnap: (PresetPane) -> Void

    // Read from SwiftUI rather than the NSView's own appearance: the island
    // forces a dark scheme on its content while its window stays Aqua.
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> PresetThumbnailView {
        let view = PresetThumbnailView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: PresetThumbnailView, context: Context) {
        update(nsView)
    }

    private func update(_ view: PresetThumbnailView) {
        view.configure(preset: preset, hoveredPaneId: hoveredPaneId, isInteractive: isInteractive,
                       isDark: colorScheme == .dark, onHover: onHover, onSnap: onSnap)
    }
}

private final class PresetThumbnailView: NSView {
    private var preset: LayoutPresetModel?
    private var hoveredPaneId: String?
    private var currentHoveredPane: PresetPane?
    private var onHover: ((PresetPane?) -> Void)?
    private var onSnap: ((PresetPane) -> Void)?
    /// False while this page is hidden behind the other mode: its tracking
    /// areas stay installed, so events must be ignored rather than relied on
    /// not to arrive.
    private var isInteractive = true
    private var isDark = true

    private var paneLayers: [String: CALayer] = [:]
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        applyPlateColors()
    }

    /// Same neutrals as the SwiftUI side: the label colour at an opacity.
    private func ink(_ alpha: CGFloat) -> CGColor {
        NSColor(white: isDark ? 1 : 0, alpha: alpha).cgColor
    }

    private func applyPlateColors() {
        layer?.borderColor = ink(0.12)
        layer?.backgroundColor = ink(0.05)
    }

    func configure(
        preset: LayoutPresetModel,
        hoveredPaneId: String?,
        isInteractive: Bool,
        isDark: Bool,
        onHover: @escaping (PresetPane?) -> Void,
        onSnap: @escaping (PresetPane) -> Void
    ) {
        // SwiftUI calls this on every update of the panel, hover text and
        // island resizes included. Only touch layers and cursor rects when
        // something they show has changed.
        let presetChanged = self.preset?.id != preset.id
        var stylesChanged = presetChanged || self.hoveredPaneId != hoveredPaneId
        self.preset = preset
        self.hoveredPaneId = hoveredPaneId
        self.onHover = onHover
        self.onSnap = onSnap
        if self.isDark != isDark {
            self.isDark = isDark
            applyPlateColors()
            stylesChanged = true
        }
        if self.isInteractive != isInteractive {
            self.isInteractive = isInteractive
            if !isInteractive, currentHoveredPane != nil {
                currentHoveredPane = nil
                stylesChanged = true
            }
            window?.invalidateCursorRects(for: self)
        }
        if presetChanged { layoutPaneLayers() }
        if stylesChanged { updateLayerStyles() }
    }

    override func layout() {
        super.layout()
        layoutPaneLayers()
        updateLayerStyles()
    }

    private func frameForPane(_ pane: PresetPane) -> CGRect {
        let margin: CGFloat = 5
        let gap: CGFloat = 3.5
        let innerW = bounds.width - (margin * 2)
        let innerH = bounds.height - (margin * 2)

        let leftEdge: CGFloat
        if pane.rect.x <= 0.001 {
            leftEdge = margin
        } else {
            leftEdge = margin + pane.rect.x * innerW + (gap / 2.0)
        }

        let rightEdge: CGFloat
        if pane.rect.x + pane.rect.width >= 0.999 {
            rightEdge = margin + innerW
        } else {
            rightEdge = margin + (pane.rect.x + pane.rect.width) * innerW - (gap / 2.0)
        }

        let topEdge: CGFloat
        if pane.rect.y <= 0.001 {
            topEdge = margin
        } else {
            topEdge = margin + pane.rect.y * innerH + (gap / 2.0)
        }

        let bottomEdge: CGFloat
        if pane.rect.y + pane.rect.height >= 0.999 {
            bottomEdge = margin + innerH
        } else {
            bottomEdge = margin + (pane.rect.y + pane.rect.height) * innerH - (gap / 2.0)
        }

        return CGRect(
            x: leftEdge,
            y: topEdge,
            width: max(4, rightEdge - leftEdge),
            height: max(4, bottomEdge - topEdge)
        )
    }

    private func layoutPaneLayers() {
        guard let preset else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let currentIds = Set(preset.panes.map(\.id))
        for (id, layer) in paneLayers where !currentIds.contains(id) {
            layer.removeFromSuperlayer()
            paneLayers.removeValue(forKey: id)
        }

        for pane in preset.panes {
            let layer: CALayer
            if let existing = paneLayers[pane.id] {
                layer = existing
            } else {
                let newLayer = CALayer()
                newLayer.cornerRadius = 5.5
                newLayer.masksToBounds = true
                self.layer?.addSublayer(newLayer)
                paneLayers[pane.id] = newLayer
                layer = newLayer
            }
            layer.frame = frameForPane(pane)
        }
        CATransaction.commit()
    }

    private func updateLayerStyles() {
        guard let preset else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        for pane in preset.panes {
            guard let layer = paneLayers[pane.id] else { continue }
            let isHovered = (hoveredPaneId == pane.id) || (currentHoveredPane?.id == pane.id)
            if isHovered {
                layer.backgroundColor = NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0).cgColor
                layer.borderColor = NSColor.clear.cgColor
                layer.borderWidth = 0
            } else {
                layer.backgroundColor = ink(isDark ? 0.16 : 0.12)
                layer.borderColor = NSColor.clear.cgColor
                layer.borderWidth = 0
            }
        }
        CATransaction.commit()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isInteractive { addCursorRect(bounds, cursor: .pointingHand) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isInteractive ? super.hitTest(point) : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [
            // The panel never becomes key, so hover tracks always.
            .activeAlways,
            .mouseMoved,
            .mouseEnteredAndExited,
            .cursorUpdate,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        window?.invalidateCursorRects(for: self)
    }

    override func cursorUpdate(with event: NSEvent) {
        guard isInteractive else { return }
        NSCursor.pointingHand.set()
    }

    private func hitPane(at pt: CGPoint) -> PresetPane? {
        guard let preset else { return nil }
        for pane in preset.panes {
            if frameForPane(pane).contains(pt) {
                return pane
            }
        }
        if bounds.contains(pt) {
            var closest: PresetPane? = nil
            var minDistance: CGFloat = .infinity
            for pane in preset.panes {
                let frame = frameForPane(pane)
                let expanded = frame.insetBy(dx: -3, dy: -3)
                if expanded.contains(pt) {
                    return pane
                }
                let center = CGPoint(x: frame.midX, y: frame.midY)
                let dist = hypot(pt.x - center.x, pt.y - center.y)
                if dist < minDistance {
                    minDistance = dist
                    closest = pane
                }
            }
            return closest
        }
        return nil
    }

    private func updateHover(to pane: PresetPane?) {
        if currentHoveredPane?.id != pane?.id {
            currentHoveredPane = pane
            updateLayerStyles()
            onHover?(pane)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard isInteractive else { return }
        NSCursor.pointingHand.set()
        let pt = convert(event.locationInWindow, from: nil)
        updateHover(to: hitPane(at: pt))
    }

    override func mouseMoved(with event: NSEvent) {
        guard isInteractive else { return }
        NSCursor.pointingHand.set()
        let pt = convert(event.locationInWindow, from: nil)
        updateHover(to: hitPane(at: pt))
    }

    override func mouseExited(with event: NSEvent) {
        guard isInteractive else { return }
        NSCursor.arrow.set()
        updateHover(to: nil)
    }

    override func mouseUp(with event: NSEvent) {
        guard isInteractive else { return }
        let pt = convert(event.locationInWindow, from: nil)
        if let hit = hitPane(at: pt) {
            onSnap?(hit)
        }
    }
}

// MARK: - Native Event Handling

/// Turns scroll events into division steps.
///
/// A notched wheel sends one event per detent, so each event is one step no
/// matter how large acceleration makes its delta. Continuous surfaces (Magic
/// Mouse, trackpad) report precise deltas: there one swipe is one step, and
/// momentum never adds more, however fast the swipe.
final class ScrollDivisionStepper {
    private var accumulator: Double = 0
    private var firedThisGesture = false
    private var lastPreciseEvent: TimeInterval = 0

    /// Distance a precise swipe travels before it counts.
    private let preciseThreshold: Double = 10

    /// +1 for the next division, -1 for the previous one, nil for none.
    func step(for event: NSEvent) -> Int? {
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? Double(event.scrollingDeltaX)
            : Double(event.scrollingDeltaY)

        guard event.hasPreciseScrollingDeltas else {
            guard delta != 0 else { return nil }
            return delta < 0 ? 1 : -1
        }

        if !event.momentumPhase.isEmpty { return nil }

        let now = event.timestamp
        let phase = event.phase
        if phase.contains(.began) || phase.contains(.mayBegin)
            // Devices that report no phases: a pause starts a new gesture.
            || (phase.isEmpty && now - lastPreciseEvent > 0.3) {
            accumulator = 0
            firedThisGesture = false
        }
        lastPreciseEvent = now
        if phase.contains(.ended) || phase.contains(.cancelled) {
            accumulator = 0
            firedThisGesture = false
            return nil
        }

        guard !firedThisGesture else { return nil }
        accumulator += delta
        guard abs(accumulator) >= preciseThreshold else { return nil }
        firedThisGesture = true
        return accumulator < 0 ? 1 : -1
    }
}

private struct ScrollWheelPassthroughRepresentable: NSViewRepresentable {
    var isInteractive: Bool
    var onScroll: (NSEvent) -> Void

    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.isInteractive = isInteractive
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelView, context: Context) {
        nsView.isInteractive = isInteractive
        nsView.onScroll = onScroll
    }

    final class ScrollWheelView: NSView {
        var isInteractive = true
        var onScroll: ((NSEvent) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard isInteractive, NSApp.currentEvent?.type == .scrollWheel else { return nil }
            return super.hitTest(point)
        }

        override func scrollWheel(with event: NSEvent) {
            onScroll?(event)
        }
    }
}

private struct MiniScreenCanvasRepresentable: NSViewRepresentable {
    var cols: Int
    var rows: Int
    var isInteractive: Bool
    var onHover: (GridCoord) -> Void
    var onMouseDown: (GridCoord) -> Void
    var onMouseDragged: (GridCoord) -> Void
    var onMouseUp: (GridCoord) -> Void
    var onMouseExited: () -> Void
    var onScroll: (NSEvent) -> Void

    func makeNSView(context: Context) -> MiniScreenCanvasView {
        let view = MiniScreenCanvasView()
        view.isInteractive = isInteractive
        view.update(cols: cols, rows: rows, onHover: onHover, onMouseDown: onMouseDown,
                    onMouseDragged: onMouseDragged, onMouseUp: onMouseUp,
                    onMouseExited: onMouseExited, onScroll: onScroll)
        return view
    }

    func updateNSView(_ nsView: MiniScreenCanvasView, context: Context) {
        if nsView.isInteractive != isInteractive {
            nsView.isInteractive = isInteractive
            nsView.window?.invalidateCursorRects(for: nsView)
        }
        nsView.update(cols: cols, rows: rows, onHover: onHover, onMouseDown: onMouseDown,
                      onMouseDragged: onMouseDragged, onMouseUp: onMouseUp,
                      onMouseExited: onMouseExited, onScroll: onScroll)
    }

    final class MiniScreenCanvasView: NSView {
        var cols: Int = 2
        var rows: Int = 1
        /// False while the grid page is hidden behind Layout Presets.
        var isInteractive = true
        var onHover: ((GridCoord) -> Void)?
        var onMouseDown: ((GridCoord) -> Void)?
        var onMouseDragged: ((GridCoord) -> Void)?
        var onMouseUp: ((GridCoord) -> Void)?
        var onMouseExited: (() -> Void)?
        var onScroll: ((NSEvent) -> Void)?

        private var trackingArea: NSTrackingArea?

        override var isFlipped: Bool { true }

        func update(cols: Int, rows: Int,
                    onHover: @escaping (GridCoord) -> Void,
                    onMouseDown: @escaping (GridCoord) -> Void,
                    onMouseDragged: @escaping (GridCoord) -> Void,
                    onMouseUp: @escaping (GridCoord) -> Void,
                    onMouseExited: @escaping () -> Void,
                    onScroll: @escaping (NSEvent) -> Void) {
            self.cols = cols
            self.rows = rows
            self.onHover = onHover
            self.onMouseDown = onMouseDown
            self.onMouseDragged = onMouseDragged
            self.onMouseUp = onMouseUp
            self.onMouseExited = onMouseExited
            self.onScroll = onScroll
        }

        override func resetCursorRects() {
            super.resetCursorRects()
            if isInteractive { addCursorRect(bounds, cursor: .crosshair) }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            isInteractive ? super.hitTest(point) : nil
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            let options: NSTrackingArea.Options = [
                // The panel never becomes key, so hover tracks always.
                .activeAlways,
                .mouseMoved,
                .mouseEnteredAndExited,
                .cursorUpdate,
                .inVisibleRect
            ]
            let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
            window?.invalidateCursorRects(for: self)
        }

        override func cursorUpdate(with event: NSEvent) {
            guard isInteractive else { return }
            NSCursor.crosshair.set()
        }

        private func gridCoord(for point: CGPoint) -> GridCoord {
            let cellW = bounds.width / CGFloat(max(1, cols))
            let cellH = bounds.height / CGFloat(max(1, rows))
            let colRaw = Int(floor(point.x / cellW))
            let rowRaw = Int(floor(point.y / cellH))
            let col = max(0, min(cols - 1, colRaw))
            let row = max(0, min(rows - 1, rowRaw))
            return GridCoord(col: col, row: row)
        }

        override func mouseEntered(with event: NSEvent) {
            guard isInteractive else { return }
            NSCursor.crosshair.set()
        }

        override func mouseMoved(with event: NSEvent) {
            guard isInteractive else { return }
            NSCursor.crosshair.set()
            let pt = convert(event.locationInWindow, from: nil)
            guard bounds.contains(pt) else { return }
            onHover?(gridCoord(for: pt))
        }

        override func mouseDown(with event: NSEvent) {
            NSCursor.crosshair.set()
            let pt = convert(event.locationInWindow, from: nil)
            onMouseDown?(gridCoord(for: pt))
        }

        override func mouseDragged(with event: NSEvent) {
            NSCursor.crosshair.set()
            let pt = convert(event.locationInWindow, from: nil)
            let clampedPt = CGPoint(
                x: max(0, min(bounds.width - 0.001, pt.x)),
                y: max(0, min(bounds.height - 0.001, pt.y))
            )
            onMouseDragged?(gridCoord(for: clampedPt))
        }

        override func mouseUp(with event: NSEvent) {
            NSCursor.crosshair.set()
            let pt = convert(event.locationInWindow, from: nil)
            let clampedPt = CGPoint(
                x: max(0, min(bounds.width - 0.001, pt.x)),
                y: max(0, min(bounds.height - 0.001, pt.y))
            )
            let coord = gridCoord(for: clampedPt)
            onMouseUp?(coord)
        }

        override func mouseExited(with event: NSEvent) {
            guard isInteractive else { return }
            NSCursor.arrow.set()
            onMouseExited?()
        }

        override func scrollWheel(with event: NSEvent) {
            guard isInteractive else { return super.scrollWheel(with: event) }
            onScroll?(event)
        }
    }
}
