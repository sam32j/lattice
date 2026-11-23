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
                payloadPicker(text.toolLabel, availableUtilities.map {
                    .init(value: $0.rawValue, title: toolTitle($0), symbol: $0.symbolName)
                })
            }
        case .tool, .quickToggle:
            // Quick toggles and the utilities that are really switches, in
            // one menu; each keeps the kind it is stored as.
            let title = FeatureStrings.quickToggles(l10n.language).pageTitle
            editorRow(title) {
                let toggles: [SettingsPopUpPicker<String>.Option] = availableQuickToggles.map {
                    .init(value: "toggle:" + $0.rawValue, title: $0.settingsTitle(text), symbol: $0.symbolName)
                }
                let tools: [SettingsPopUpPicker<String>.Option] = availableControlTools.enumerated().map { index, tool in
                    .init(value: "tool:" + tool.rawValue, title: toolTitle(tool), symbol: tool.symbolName,
                          separatorBefore: index == 0 && !toggles.isEmpty)
                }
                SettingsPopUpPicker(title: title, options: toggles + tools,
                                    selection: controlBinding, exactWidth: Self.fieldWidth)
            }
        case .windowLayout:
            let windowText = FeatureStrings.windowLayout(l10n.language)
            editorRow(windowText.title) {
                payloadPicker(windowText.title, WindowLayoutAction.allCases.map {
                    .init(value: $0.rawValue, title: $0.radialTitle(text), symbol: $0.symbolName)
                })
            }
        case .media:
            editorRow(text.mediaLabel) {
                payloadPicker(text.mediaLabel, [
                    .init(value: RadialMenuMediaKey.playPause.rawValue, title: text.mediaPlayPause),
                    .init(value: RadialMenuMediaKey.previousTrack.rawValue, title: text.mediaPrevious),
                    .init(value: RadialMenuMediaKey.nextTrack.rawValue, title: text.mediaNext),
                    .init(value: RadialMenuMediaKey.nowPlaying.rawValue, title: text.mediaNowPlaying),
                ])
            }
        case .submenu:
            EmptyView()
        }
    }

    /// Every menu of the editor: the same pop-up at exactly the field width,
    /// so the controls line up whatever their titles.
    func payloadPicker(_ title: String, _ options: [SettingsPopUpPicker<String>.Option]) -> some View {
        SettingsPopUpPicker(title: title, options: options, selection: $item.payload, exactWidth: Self.fieldWidth)
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
