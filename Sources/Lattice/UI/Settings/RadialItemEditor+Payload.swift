// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension RadialItemEditor {
    /// The target row for the chosen kind of action, in the same one-line
    /// shape as the rest of the editor. Errors show in the control or as a
    /// mark beside it, never as a paragraph.
    @ViewBuilder
    var payloadEditor: some View {
        switch item.kind {
        case .app:
            editorRow(text.kindApp) {
                Button(chooseTitle) { choose(applications: true) }
            }
        case .file:
            editorRow(text.kindFile) {
                Button(chooseTitle) { choose(applications: false) }
            }
        case .url:
            editorRow(text.kindURL,
                      status: urlIsInvalid && !item.payload.isEmpty ? .problem(text.urlInvalid) : nil) {
                TextField(text.kindURL, text: $item.payload, prompt: Text(text.urlPlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: Self.fieldWidth)
            }
        case .shortcut:
            editorRow(text.kindShortcut) {
                CompactShortcutBindingRecorder(
                    recordingID: "radial-item-shortcut",
                    shortcut: GlobalShortcut(storageValue: item.payload),
                    isEnabled: true,
                    emptyTitle: l10n.s.shortcutNone,
                    canClear: !item.payload.isEmpty,
                    errorText: $shortcutError,
                    onClear: { item.payload = "" },
                    onReset: {},
                    onCapture: { item.payload = $0.storageValue })
            }
        case .tool where item.tool?.isControl != true:
            editorRow(text.toolLabel) {
                menuPicker(text.toolLabel) {
                    ForEach(availableUtilities) { tool in
                        Label(toolTitle(tool), systemImage: tool.symbolName)
                            .tag(tool.rawValue)
                    }
                }
            }
        case .tool, .quickToggle:
            // Quick toggles and the utilities that are really switches, in
            // one menu; each keeps the kind it is stored as.
            let title = FeatureStrings.quickToggles(l10n.language).pageTitle
            editorRow(title) {
                Picker(title, selection: controlBinding) {
                    ForEach(availableQuickToggles) { action in
                        Label(action.settingsTitle(text), systemImage: action.symbolName)
                            .tag("toggle:" + action.rawValue)
                    }
                    if !availableQuickToggles.isEmpty, !availableControlTools.isEmpty { Divider() }
                    ForEach(availableControlTools) { tool in
                        Label(toolTitle(tool), systemImage: tool.symbolName)
                            .tag("tool:" + tool.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: Self.fieldWidth)
            }
        case .windowLayout:
            let windowText = FeatureStrings.windowLayout(l10n.language)
            editorRow(windowText.title) {
                menuPicker(windowText.title) {
                    ForEach(WindowLayoutAction.allCases) { action in
                        Label(action.radialTitle(text), systemImage: action.symbolName)
                            .tag(action.rawValue)
                    }
                }
            }
        case .media:
            editorRow(text.mediaLabel) {
                menuPicker(text.mediaLabel) {
                    Text(text.mediaPlayPause).tag(RadialMenuMediaKey.playPause.rawValue)
                    Text(text.mediaPrevious).tag(RadialMenuMediaKey.previousTrack.rawValue)
                    Text(text.mediaNext).tag(RadialMenuMediaKey.nextTrack.rawValue)
                    Text(text.mediaNowPlaying).tag(RadialMenuMediaKey.nowPlaying.rawValue)
                }
            }
        case .submenu:
            EmptyView()
        }
    }

    func menuPicker<Options: View>(_ title: String, @ViewBuilder options: () -> Options) -> some View {
        Picker(title, selection: $item.payload) { options() }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: Self.fieldWidth)
    }

    func toolTitle(_ tool: RadialMenuTool) -> String {
        tool.feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language))
    }

    /// A quick toggle or a control tool, as one choice.
    var controlBinding: Binding<String> {
        Binding(get: {
            (item.kind == .tool ? "tool:" : "toggle:") + item.payload
        }, set: { tagged in
            if tagged.hasPrefix("tool:") {
                item.kind = .tool
                item.payload = String(tagged.dropFirst("tool:".count))
            } else {
                item.kind = .quickToggle
                item.payload = String(tagged.dropFirst("toggle:".count))
            }
        })
    }
}
