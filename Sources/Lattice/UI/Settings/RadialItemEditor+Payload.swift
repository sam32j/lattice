import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension RadialItemEditor {
    @ViewBuilder
    var payloadEditor: some View {
        switch item.kind {
        case .app:
            LabeledContent(text.kindApp) {
                Button(chooseTitle) { choose(applications: true) }
            }
        case .file:
            LabeledContent(text.kindFile) {
                Button(chooseTitle) { choose(applications: false) }
            }
        case .url:
            VStack(alignment: .leading, spacing: 6) {
                TextField(text.kindURL, text: $item.payload, prompt: Text(text.urlPlaceholder))
                    .onChange(of: item.payload) { _, _ in
                        faviconStatus = nil
                    }

                HStack(spacing: 8) {
                    Button {
                        fetchWebsiteFavicon()
                    } label: {
                        if isFetchingFavicon {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(text.fetchFaviconLoading)
                            }
                        } else {
                            Text(text.fetchFaviconButton)
                        }
                    }
                    .disabled(isFetchingFavicon || item.payload.trimmingCharacters(in: .whitespaces).isEmpty || urlIsInvalid)

                    if let faviconStatus {
                        switch faviconStatus {
                        case .success:
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(text.fetchFaviconSuccess)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        case .error:
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(text.fetchFaviconError)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Text(text.fetchFaviconDisclaimer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .shortcut:
            LabeledContent(text.kindShortcut) {
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
            Picker(text.toolLabel, selection: $item.payload) {
                ForEach(availableTools) { tool in
                    Text(tool.feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)))
                        .tag(tool.rawValue)
                }
            }
        case .quickToggle:
            let quickToggleText = FeatureStrings.quickToggles(l10n.language)
            Picker(quickToggleText.pageTitle, selection: $item.payload) {
                ForEach(availableQuickToggles) { action in
                    Label(action.radialTitle, systemImage: action.symbolName)
                        .tag(action.rawValue)
                }
            }
        case .windowLayout:
            let windowText = FeatureStrings.windowLayout(l10n.language)
            Picker(windowText.title, selection: $item.payload) {
                ForEach(WindowLayoutAction.allCases) { action in
                    Label(action.title(windowText), systemImage: action.symbolName)
                        .tag(action.rawValue)
                }
            }
        case .media:
            Picker(text.mediaLabel, selection: $item.payload) {
                Text(text.mediaPlayPause).tag(RadialMenuMediaKey.playPause.rawValue)
                Text(text.mediaPrevious).tag(RadialMenuMediaKey.previousTrack.rawValue)
                Text(text.mediaNext).tag(RadialMenuMediaKey.nextTrack.rawValue)
                Text(text.mediaNowPlaying).tag(RadialMenuMediaKey.nowPlaying.rawValue)
            }
        case .submenu:
            EmptyView()
        }
    }

}
