import SwiftUI
import EventKit

extension NotchSettings {
    @ViewBuilder var musicModuleOptions: some View {
        let music = FeatureStrings.notchMusicExtras(l10n.language)
        switchRow("waveform", text.playingMusic, isOn: $showPlayingMusic)
        switchRow("play.rectangle", music.includeOtherPlayers, isOn: $includeOtherPlayers)
        SettingsRow(symbol: "arrow.up.forward.app", title: music.preferredPlayer) {
            Picker(music.preferredPlayer, selection: $preferredPlayer) {
                Text(music.automaticSource).tag(NotchPreferredPlayer.automatic)
                ForEach(NotchPreferredPlayer.choices(in: preferredPlayers ?? [], including: preferredPlayer), id: \.bundleID) { app in
                    Text(app.name).tag(app.bundleID)
                }
            }
            .labelsHidden()
        }
        .task {
            guard let choices = await NotchPreferredPlayer.loadInstalled(), !Task.isCancelled else { return }
            preferredPlayers = choices
        }
        switchRow("text.quote", music.enableLyrics,
                  caption: "Use online service to find lyrics. Track info will be sent to lrclib.net.",
                  isOn: islandFeatureBinding(.notchLyrics, value: Binding(
                      get: { lyricsEnabled },
                      set: { enabled in
                          lyricsEnabled = enabled
                          lyricsOnline = enabled
                          UserDefaults.standard.set(enabled, forKey: DefaultsKey.notchLyricsOnline)
                      }
                  )))
        switchRow("list.bullet", music.enableQueue,
                  isOn: islandFeatureBinding(.notchQueue, value: $queueEnabled))
        NotchAudioVisualizerToggle(music.liveEqualizer,
            caption: NotchAudioLevelSupport.isSupported ? music.liveEqualizerHint : music.liveEqualizerUnavailable,
            isOn: islandFeatureBinding(.notchLiveEqualizer, value: $liveEqualizer),
            contextEnabled: enabled && moduleBinding(.music).wrappedValue)
            .disabled(!NotchAudioLevelSupport.isSupported)
    }
}
