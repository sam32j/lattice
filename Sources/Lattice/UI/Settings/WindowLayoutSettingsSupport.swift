import SwiftUI

extension WindowLayoutSettings {
    var directionalTrigger: WindowDirectionalTrigger {
        WindowDirectionalTrigger(storageValue: directionalShortcutRaw) ?? .key(.windowDirectionalDefault)
    }

    var directionalDisplayShortcut: GlobalShortcut? {
        guard directionalEnabled, case .key(let shortcut) = directionalTrigger else { return nil }
        return shortcut
    }

    func saveDirectionalShortcut(_ shortcut: GlobalShortcut) {
        if let conflict = service.directionalShortcutConflictTitle(shortcut) {
            directionalError = String(format: l10n.s.shortcutConflictFormat, conflict)
            return
        }
        saveDirectionalTrigger(.key(shortcut))
    }

    func saveDirectionalTrigger(_ trigger: WindowDirectionalTrigger) {
        directionalError = nil
        directionalShortcutRaw = trigger.storageValue
        directionalEnabled = true
        service.syncWithPreferences()
    }

    /// The gaps take effect on the next placement — the engine reads them
    /// per apply — so the pickers need no service sync.
    func gapPicker(_ title: String, selection: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(WindowLayoutGaps.presets, id: \.self) { value in
                    Text(gapPresetTitle(value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    func gapPresetTitle(_ value: Int) -> String {
        let name: String
        switch value {
        case 0: return text.gapNone
        case 8: name = text.gapTiny
        case 16: name = text.gapSmall
        case 32: name = text.gapMedium
        case 64: name = text.gapLarge
        case 128: name = text.gapExtraLarge
        default: return "\(value) px"
        }
        return "\(name) (\(value) px)"
    }

    var marginSlider: some View {
        WindowLayoutMarginSlider(title: text.marginEdge, marginPercent: $marginPercent)
    }

    func refreshSystemTilingState() {
        systemTilingEnabled = WindowEdgeSnapSupport.isSystemTilingEnabled
        WindowLayoutService.shared.syncWithPreferences()
    }

    static let halfActions: [WindowLayoutAction] = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf, .centerHalf,
    ]
    static let thirdActions: [WindowLayoutAction] = [
        .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds, .centerTwoThirds,
        .topThird, .middleThird, .bottomThird, .topTwoThirds, .bottomTwoThirds,
    ]
    static let quarterRowActions: [WindowLayoutAction] = [
        .topQuarter, .upperMiddleQuarter, .lowerMiddleQuarter, .bottomQuarter,
    ]
    static let quarterColumnActions: [WindowLayoutAction] = [
        .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter,
    ]
    static let sixthActions: [WindowLayoutAction] = [
        .topLeftSixth, .topCenterSixth, .topRightSixth,
        .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth,
    ]
    static let cornerActions: [WindowLayoutAction] = [
        .topLeft, .topRight, .bottomLeft, .bottomRight,
    ]

    /// The placement families, grouped so the form body stays within the
    /// ten-view ViewBuilder limit.
    @ViewBuilder
    var placementSections: some View {
        Divider()
        VStack(alignment: .leading, spacing: 13) {
            Text(text.halves).font(.headline)
            ForEach(Self.halfActions) { action in
                actionRow(action)
            }
            Toggle(text.sideRepeatCycle, isOn: $sideRepeatCyclesThirds)
            Text(text.sideRepeatCycleCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        actionSection(text.thirds, Self.thirdActions)
        actionSection(text.quarterRows, Self.quarterRowActions)
        actionSection(text.quarterColumns, Self.quarterColumnActions)
        actionSection(text.sixths, Self.sixthActions)
        actionSection(text.corners, Self.cornerActions)
    }

    /// One section per placement family. Building the rows from an array keeps
    /// each section clear of the ten-view ViewBuilder limit and keeps the form
    /// body small enough for the type checker.
    @ViewBuilder
    func actionSection(_ title: String, _ actions: [WindowLayoutAction]) -> some View {
        Divider()
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.headline)
            ForEach(actions) { action in
                actionRow(action)
            }
        }
    }

    /// One row per action: try-it button on the left, the action's global
    /// shortcut recorder inline on the right — every action is adjustable
    /// right where it lives, no separate shortcut list to hunt for.
    func actionRow(_ action: WindowLayoutAction) -> some View {
        WindowLayoutActionRow(action: action,
                              title: title(for: action),
                              symbol: symbol(for: action),
                              applyEnabled: permissions.accessibility,
                              shortcutEnabled: permissions.accessibility)
    }

    func title(for action: WindowLayoutAction) -> String {
        action.title(text)
    }

    func symbol(for action: WindowLayoutAction) -> String {
        action.symbolName
    }

    var resultMessage: String? {
        switch service.lastResult {
        case .success(let restored): return restored ? text.restored : text.done
        case .failure(.missingAccessibility): return text.missingPermission
        case .failure(.noWindow): return text.noWindow
        case .failure(.noRestore): return text.noRestore
        case .failure(.failed): return text.failed
        case nil: return nil
        }
    }

    var resultColor: Color {
        switch service.lastResult {
        case .success: return .green
        case .failure: return .orange
        case nil: return .secondary
        }
    }
}

private struct WindowLayoutMarginSlider: View {
    let title: String
    @Binding var marginPercent: Double
    @State private var isSliding = false

    private var marginPixelValue: Int {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1440
        return Int(round(screenWidth * (WindowLayoutMargin.sanitizedPercent(marginPercent) / 100.0)))
    }

    private let sliderWidth: CGFloat = 140

    var body: some View {
        HStack {
            Label(title, systemImage: "rectangle.inset.filled")
            Spacer()
            ZStack(alignment: .topLeading) {
                Slider(
                    value: Binding(
                        get: { WindowLayoutMargin.sanitizedPercent(marginPercent) },
                        set: { marginPercent = round(WindowLayoutMargin.sanitizedPercent($0)) }
                    ),
                    in: WindowLayoutMargin.percentRange,
                    onEditingChanged: { editing in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isSliding = editing
                        }
                    }
                )
                .frame(width: sliderWidth)
                .help("\(marginPixelValue) px")

                if isSliding {
                    let fraction = CGFloat(WindowLayoutMargin.sanitizedPercent(marginPercent) / WindowLayoutMargin.percentRange.upperBound)
                    let thumbX = 8 + fraction * (sliderWidth - 16)
                    let clampedX = min(max(thumbX - 22, 0), sliderWidth - 44)

                    Text("\(marginPixelValue) px")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .fixedSize()
                        .offset(x: clampedX, y: -24)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: sliderWidth)
        }
    }
}
