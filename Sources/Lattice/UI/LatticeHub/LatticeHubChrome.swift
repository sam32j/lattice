// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension LatticeHubView {
    var header: some View {
        VStack(spacing: 6) {
            ZStack {
                HubDragHandle()
                    .frame(height: 30)
                BrandMark(width: 52, tint: colorScheme == .light ? Color(white: 0.03) : .white)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                HStack {
                    if launcher.activeUtility != nil {
                        backButton
                    } else {
                        closeButton
                    }
                    Spacer()
                    if launcher.activeUtility != nil {
                        closeButton
                    } else if launcher.isEditing {
                        doneEditingButton
                    } else {
                        toolsMenuButton
                    }
                }
            }
        }
    }

    var doneEditingButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = false }
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(l10n.s.menuClose)
        .accessibilityLabel(l10n.s.menuClose)
    }

    var backButton: some View {
        Button { launcher.closeUtility() } label: {
            Image(systemName: "chevron.backward.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(l10n.s.navigationBack)
        .accessibilityLabel(l10n.s.navigationBack)
    }

    var toolsMenuButton: some View {
        Menu {
            Button(customizationText.manageTools + "…") {
                withAnimation(.easeInOut(duration: 0.22)) { launcher.isEditing = true }
            }
            .disabled(!launcher.canManageTools)

            Button(customizationText.openSettings + "…") {
                openSettingsToTools()
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
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

