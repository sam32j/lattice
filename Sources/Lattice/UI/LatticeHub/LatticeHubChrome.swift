// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct HubHeaderButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var overrideForeground: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(overrideForeground ?? (isSelected || configuration.isPressed ? Color.primary : Color.secondary))
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HubToolsMenuButton: View {
    let customizationText: HubCustomizationStrings
    @ObservedObject var launcher: LatticeHubService
    let onOpenSettings: () -> Void
    var appearance: NSAppearance? = nil

    @State private var anchor = NotchMenuAnchor()
    @State private var isMenuOpen = false

    var body: some View {
        Button {
            anchor.popUp([
                NotchMenuItem(
                    title: customizationText.manageTools + "…",
                    enabled: launcher.canManageTools,
                    action: {
                        withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = true }
                    }
                ),
                NotchMenuItem(
                    title: customizationText.openSettings + "…",
                    action: onOpenSettings
                )
            ], appearance: appearance)
        } label: {
            Image(systemName: isMenuOpen ? "gearshape.fill" : "gearshape")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(HubHeaderButtonStyle(isSelected: isMenuOpen))
        .background(NotchMenuAnchorView(anchor: anchor))
        .focusable(false)
        .onAppear {
            anchor.onMenuOpenChanged = { open in
                isMenuOpen = open
            }
        }
        .help(customizationText.tools)
        .accessibilityLabel(customizationText.toolsMenu)
    }
}

extension LatticeHubView {
    var header: some View {
        VStack(spacing: 6) {
            ZStack {
                HubDragHandle()
                    .frame(height: 30)
                if let utility = launcher.activeUtility {
                    Text(title(for: utility))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(height: 30)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    BrandMark(width: 52, tint: colorScheme == .light ? Color(white: 0.03) : .white)
                        .frame(height: 30)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                HStack(spacing: 6) {
                    if launcher.activeUtility != nil {
                        backButton
                    } else {
                        HStack(spacing: 6) {
                            toolsMenuButton
                            if updateOffered {
                                updateButton
                            }
                        }
                    }
                    Spacer()
                    if launcher.activeUtility != nil {
                        pinButton
                        closeButton
                    } else if launcher.isEditing {
                        pinButton
                        doneEditingButton
                    } else {
                        pinButton
                        closeButton
                    }
                }
            }
        }
    }

    var updateButton: some View {
        Button(action: service.showUpdate) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HubHeaderButtonStyle(overrideForeground: .blue))
        .focusable(false)
        .help(updateTooltip)
        .accessibilityLabel(updateTooltip)
    }

    var updateTooltip: String {
        switch updates.state {
        case let .available(version):
            return "\(l10n.s.updateBannerTitle): \(version)"
        default:
            return l10n.s.updateBannerTitle
        }
    }

    var pinButton: some View {
        Button {
            launcher.isPinned.toggle()
        } label: {
            Image(systemName: launcher.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HubHeaderButtonStyle(isSelected: launcher.isPinned))
        .focusable(false)
        .help(launcher.isPinned ? FeatureStrings.notch(l10n.language).unpin : FeatureStrings.notch(l10n.language).pin)
        .accessibilityLabel(launcher.isPinned ? FeatureStrings.notch(l10n.language).unpin : FeatureStrings.notch(l10n.language).pin)
    }

    var doneEditingButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = false }
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HubHeaderButtonStyle(isSelected: true))
        .focusable(false)
        .help(l10n.s.doneButton)
        .accessibilityLabel(l10n.s.doneButton)
    }

    var editHint: some View {
        Text(l10n.s.launcherEditHint)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    var closeButton: some View {
        Button { launcher.hide() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HubHeaderButtonStyle())
        .focusable(false)
        .help(l10n.s.menuClose)
        .accessibilityLabel(l10n.s.menuClose)
    }

    var backButton: some View {
        Button {
            if launcher.activeUtility == .deviceControls,
               DeviceControlsNavigationState.shared.currentSubpage == .appVolumes {
                DeviceControlsNavigationState.shared.currentSubpage = .main
            } else {
                if launcher.activeUtility == .deviceControls {
                    DeviceControlsNavigationState.shared.resetSubpage()
                }
                launcher.closeUtility()
            }
        } label: {
            Image(systemName: "chevron.backward.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(HubHeaderButtonStyle())
        .focusable(false)
        .help(l10n.s.navigationBack)
        .accessibilityLabel(l10n.s.navigationBack)
    }

    var toolsMenuButton: some View {
        HubToolsMenuButton(
            customizationText: customizationText,
            launcher: launcher,
            onOpenSettings: openSettingsToTools,
            appearance: NSAppearance(named: colorScheme == .light ? .aqua : .darkAqua)
        )
    }

    var islandToolsMenuButton: some View {
        NotchMenuButton(
            title: customizationText.toolsMenu,
            items: [
                NotchMenuItem(
                    title: customizationText.manageTools + "…",
                    enabled: launcher.canManageTools,
                    action: {
                        withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = true }
                    }
                ),
                NotchMenuItem(
                    title: customizationText.openSettings + "…",
                    action: {
                        openSettingsToTools()
                    }
                )
            ],
            cornerRadius: 9,
            lifts: true
        ) {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .help(customizationText.tools)
        .accessibilityLabel(customizationText.toolsMenu)
    }

    func openSettingsToTools() {
        launcher.hide()
        SettingsRouter.shared.request(FeatureSettingsDestination(.launcherGrid))
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }

    var emptyState: some View {
        let isStateA = launcher.canManageTools && (!launcher.hiddenItems.isEmpty || !launcher.hiddenControls.isEmpty)
        let headline = isStateA ? customizationText.allHidden : customizationText.noneAvailable
        let bodyText = isStateA ? customizationText.chooseTools : customizationText.enableTools
        let buttonText = isStateA ? customizationText.manageTools : customizationText.openSettings
        let iconName = isStateA ? "eye.slash.fill" : "square.dashed"

        return VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(headline)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Text(bodyText)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                if isStateA {
                    withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = true }
                } else {
                    openSettingsToTools()
                }
            } label: {
                Text(buttonText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(buttonText)
            .opacity(launcher.isEditing ? 0 : 1)
            .disabled(launcher.isEditing)
            .accessibilityHidden(launcher.isEditing)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: notchSize == nil ? 140 : nil, alignment: .center)
        .padding(.vertical, notchSize == nil ? 20 : 6)
        .frame(height: notchSize == nil ? nil : NotchLayout.hubEmptyHeight)
        .accessibilityIdentifier("hub-empty-state")
    }

    var footer: some View {
        HStack(spacing: 5) {
            if GlobalShortcutRole.quickLauncher.savedShortcut.isValid {
                Image(systemName: "keyboard")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                Text(GlobalShortcutRole.quickLauncher.savedShortcut.displayString)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("Esc")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

}

private struct HubDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.identifier = NSUserInterfaceItemIdentifier("hub-drag-handle")
        return view
    }
    func updateNSView(_ nsView: DragHandleView, context: Context) {}

    final class DragHandleView: NSView {
        override var focusRingType: NSFocusRingType { get { .none } set {} }
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            window.performDrag(with: event)
        }
    }
}

