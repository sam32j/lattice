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
        Picker(title, selection: selection) {
            ForEach(WindowLayoutGaps.presets, id: \.self) { value in
                Text(gapPresetTitle(value)).tag(value)
            }
        }
        .pickerStyle(.menu)
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
        HStack(spacing: 12) {
            Slider(value: Binding(
                get: { WindowLayoutMargin.sanitizedPercent(marginPercent) },
                set: { marginPercent = WindowLayoutMargin.sanitizedPercent($0) }
            ), in: WindowLayoutMargin.percentRange, step: 1) {
                Text(text.marginPerEdge)
            }
            Text(WindowLayoutMargin.sanitizedPercent(marginPercent) / 100,
                 format: .percent.precision(.fractionLength(0)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
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
