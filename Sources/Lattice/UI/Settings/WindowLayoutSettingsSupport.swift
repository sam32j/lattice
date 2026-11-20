import SwiftUI

extension WindowLayoutSettings {
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
        switch value {
        case 0: return text.gapNone
        case 8: return text.gapTiny
        case 16: return text.gapSmall
        case 32: return text.gapMedium
        case 64: return text.gapLarge
        case 128: return text.gapExtraLarge
        default: return "\(value) px"
        }
    }

    func refreshSystemTilingState() {
        systemTilingEnabled = WindowEdgeSnapSupport.isSystemTilingEnabled
        WindowLayoutService.shared.syncWithPreferences()
    }

    static let splitActions: [WindowLayoutAction] = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf, .centerColumn, .centerRow,
    ]
    static let quarterActions: [WindowLayoutAction] = [
        .topLeft, .topRight, .bottomLeft, .bottomRight,
        .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter,
        .topQuarter, .upperMiddleQuarter, .lowerMiddleQuarter, .bottomQuarter,
    ]
    static let gridActions: [WindowLayoutAction] = [
        .topLeftSixth, .topCenterSixth, .topRightSixth,
        .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth,
    ]
}

extension WindowLayoutShortcutsSettings {
    var directionalTrigger: WindowDirectionalTrigger {
        WindowDirectionalTrigger(storageValue: directionalShortcutRaw) ?? .key(.windowDirectionalDefault)
    }

    var directionalDisplayShortcut: GlobalShortcut? {
        guard directionalEnabled, case .key(let shortcut) = directionalTrigger else { return nil }
        return shortcut
    }

    func saveDirectionalShortcut(_ shortcut: GlobalShortcut) {
        if let conflict = service.directionalShortcutConflictTitle(shortcut) {
            conflictAlert = ShortcutConflictAlert(shortcut: shortcut, assignedBehavior: conflict)
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

    /// The placement families, grouped so the form body stays within the
    /// ten-view ViewBuilder limit.
    @ViewBuilder
    var placementSections: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(text.halves).font(.headline)
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 21, height: 21)
                    .contentShape(Rectangle())
                    .overlay { StatusTooltip(message: text.repeatCycleTooltip, opensOnClick: true) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(text.repeatCycleTooltip)
            }
            ForEach(WindowLayoutSettings.splitActions) { action in
                actionRow(action)
            }
        }
        actionSection(text.quarters, WindowLayoutSettings.quarterActions)
        actionSection(text.sixths, WindowLayoutSettings.gridActions)
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
                              shortcutEnabled: permissions.accessibility,
                              onConflict: { conflictAlert = $0 })
    }

    func title(for action: WindowLayoutAction) -> String {
        action.title(text)
    }

    func symbol(for action: WindowLayoutAction) -> String {
        action.symbolName
    }
}
