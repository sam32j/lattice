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
                    .frame(width: 220)
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
                    onClear: {
                        item.payload = ""
                        shortcutError = nil
                    },
                    onReset: {},
                    onCapture: {
                        item.payload = $0.storageValue
                        shortcutError = nil
                    })
            }
        case .tool:
            editorRow(text.toolLabel) {
                menuPicker(text.toolLabel) {
                    ForEach(availableTools) { tool in
                        Label(tool.feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)),
                              systemImage: tool.symbolName)
                            .tag(tool.rawValue)
                    }
                }
            }
        case .quickToggle:
            let title = FeatureStrings.quickToggles(l10n.language).pageTitle
            editorRow(title) {
                menuPicker(title) {
                    ForEach(availableQuickToggles) { action in
                        Label(action.settingsTitle(text), systemImage: action.symbolName)
                            .tag(action.rawValue)
                    }
                }
            }
        case .windowLayout:
            let windowText = FeatureStrings.windowLayout(l10n.language)
            editorRow(windowText.title) {
                menuPicker(windowText.title) {
                    ForEach(WindowLayoutAction.allCases) { action in
                        Label(action.title(windowText), systemImage: action.symbolName)
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
            .fixedSize()
    }
}
