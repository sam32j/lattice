import SwiftUI
import EventKit

extension NotchSettings {
    func islandFeatureBinding(_ feature: AppFeature, value: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { feature.isAvailable && value.wrappedValue }, set: { enabled in
            value.wrappedValue = enabled
            features.setIslandFeature(feature, enabled: enabled)
        })
    }

    var restsWithMascot: Bool {
        enabled && !(hover && hideUntilHover) && mascotEnabled && !mascotHidesWhenIdle && features.isAvailable(.notchMascot)
    }

    /// The companion where it rests, beside a camera drawn black on black.
    var restingMascot: some View {
        let look = NotchMascotLook(style: NotchMascotStyle(rawValue: mascotStyle) ?? .minimal,
                                   shape: NotchMascotShape(rawValue: mascotShape) ?? .ball,
                                   palette: NotchMascotPalette(rawValue: mascotPalette) ?? .pearl)
        let right = NotchMascotSide(rawValue: mascotSide) == .right
        return HStack(spacing: 14) {
            if right { Color.clear.frame(width: 12, height: 12) }
            else { NotchMascotView(look: look, size: 12, idles: false).frame(width: 12, height: 12) }
            RoundedRectangle(cornerRadius: 4).fill(.black).frame(width: 20, height: 12)
            if right { NotchMascotView(look: look, size: 12, idles: false).frame(width: 12, height: 12) }
            else { Color.clear.frame(width: 12, height: 12) }
        }
    }

    /// A resting choice. One the island cannot rest with just now stays
    /// choosable, dimmed, with what brings it back under it. The choice the
    /// island rests with is marked, and a saved one that waits keeps a fainter
    /// mark.
    func idleChoice(_ item: NotchIdleContent, title: String, symbol: String,
                            reason: String? = nil, fix: @escaping () -> Void = {}) -> some View {
        let waits = reason != nil && !NotchSupport.canRest(with: item)
        let marked = restingChoice == item || (waits && idle == item.rawValue)
        return VStack(spacing: 6) {
            Button { idle = item.rawValue } label: {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        if item == .none, restsWithMascot {
                            restingMascot
                        } else if item != .none {
                            Image(systemName: symbol).font(.system(size: 11))
                            Color.clear.frame(width: 20, height: 12)
                            if item == .battery || item == .agents { Text(item == .agents ? "62%" : "76%").font(.system(size: 9, weight: .medium)) }
                            else { Image(systemName: item == .music ? "waveform" : "minus").font(.system(size: 9)) }
                        } else { Color.clear.frame(width: 50, height: 12) }
                    }.foregroundStyle(.white).padding(10).background(.black, in: Capsule())
                    Text(title).font(.system(size: 11, weight: .medium))
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(marked ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityAddTraits(restingChoice == item ? .isSelected : [])
                // VoiceOver selects what the island rests with. A saved choice
                // that waits says it is hidden from the island, and the link
                // under it says why.
                .accessibilityValue(waits && idle == item.rawValue ? editor.hiddenInIsland : "")
                .opacity(waits ? 0.45 : 1)
            if waits, let reason {
                Button(reason, action: fix)
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    func destination(_ title: String, symbol: String, value: Binding<Bool>, available: Bool = true) -> some View {
        SettingsChoiceRow(symbol: symbol, title: title, selection: value) {
            Text(text.title).tag(true)
            Text(editor.separate).tag(false)
        }.disabled(!available)
    }

    /// An option with its icon, one line and a switch, like every other page.
    func switchRow(_ symbol: String, _ title: String, caption: String? = nil, isOn: Binding<Bool>) -> some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch)
        }
    }

    func dimensionSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, fallback: Double) -> some View {
        let bounded = Binding(get: { NotchSize.clamped(value.wrappedValue, to: range, fallback: fallback) },
                              set: { value.wrappedValue = NotchSize.clamped($0, to: range, fallback: fallback) })
        return GridRow {
            // The slider carries the name for VoiceOver.
            Text(title).fixedSize().accessibilityHidden(true)
            Slider(value: bounded, in: range, step: 10) { Text(title) }.labelsHidden()
            Text(Int(bounded.wrappedValue), format: .number)
                .monospacedDigit().foregroundStyle(.secondary).frame(width: 38)
        }
    }

    /// A correction around zero, signed so the untouched value reads as none.
    func fitSlider(_ title: String, card: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double) -> some View {
        let bounded = Binding(get: { NotchSize.clamped(value.wrappedValue, to: range, fallback: 0) },
                              set: { value.wrappedValue = NotchSize.clamped($0, to: range, fallback: 0) })
        let formatted = bounded.wrappedValue.formatted(.number.sign(strategy: .always(includingZero: false))
            .precision(.fractionLength(0...1)).locale(Locale(identifier: l10n.language.rawValue)))
        return GridRow {
            Text(title).fixedSize().accessibilityHidden(true)
            // Other cards have sliders with the same names.
            Slider(value: bounded, in: range, step: step) { Text("\(card), \(title)") }.labelsHidden()
                .accessibilityValue(formatted)
            Text(formatted).monospacedDigit().foregroundStyle(.secondary).frame(width: 38)
        }
    }
    var orderedShortcuts: [NotchControlItem] {
        let stored = controlOrder.split(separator: ",").compactMap { NotchControlItem(rawValue: String($0)) }
        var seen = Set<NotchControlItem>()
        return (stored + NotchControlItem.allCases).filter {
            !$0.isLevel && $0 != .music && seen.insert($0).inserted
        }
    }

    func controlBinding(_ item: NotchControlItem) -> Binding<Bool> {
        Binding {
            !hiddenControls.split(separator: ",").contains(Substring(item.rawValue))
        } set: { shown in
            var values = Set(hiddenControls.split(separator: ",").map(String.init))
            if shown { values.remove(item.rawValue) } else { values.insert(item.rawValue) }
            hiddenControls = values.sorted().joined(separator: ",")
        }
    }

    func moduleBinding(_ module: NotchModule) -> Binding<Bool> {
        Binding {
            (module != .timer || timerEnabled) && (module != .camera || cameraEnabled)
                && (module != .calendar || calendarEnabled) && (module != .notifications || notificationsEnabled)
                && (module != .agents || agentsEnabled) && (module != .watch || watchEnabled)
                && (module != .videoDownloader || (UserDefaults.standard.bool(forKey: DefaultsKey.videoDownloaderEnabled) && (UserDefaults.standard.object(forKey: DefaultsKey.notchVideoDownloader) as? Bool ?? true)))
                && (module != .snippets || (UserDefaults.standard.object(forKey: DefaultsKey.notchSnippetsWindow) as? Bool ?? true))
                && !hidden.split(separator: ",").contains { NotchModule(rawValue: String($0)) == module }
        } set: { shown in
            if module == .timer { timerEnabled = shown }
            if module == .camera { cameraEnabled = shown }
            if module == .calendar { calendarEnabled = shown }
            if module == .notifications { notificationsEnabled = shown }
            if module == .agents { agentsEnabled = shown }
            if module == .watch { watchEnabled = shown }
            if module == .videoDownloader {
                UserDefaults.standard.set(shown, forKey: DefaultsKey.notchVideoDownloader)
            }
            if module == .snippets {
                UserDefaults.standard.set(shown, forKey: DefaultsKey.notchSnippetsWindow)
            }
            var values = Set(hidden.split(separator: ",").map(String.init))
            if shown {
                values = values.filter { NotchModule(rawValue: $0) != module }
            } else { values.insert(module.rawValue) }
            hidden = values.sorted().joined(separator: ",")
        }
    }

    var configuration: [String] {
        [String(enabled), String(calendarEnabled), String(calendarCountdown), String(calendarTimeLeft),
         String(notificationsEnabled), String(dismissNativeNotifications), String(gesturesEnabled),
         String(lyricsEnabled), String(lyricsOnline), String(browserCovers), String(queueEnabled), String(liveEqualizer),
         String(showPlayingMusic), String(includeOtherPlayers), idle, hiddenControls, controlOrder, size,
         String(timerEnabled), String(timerSoundEnabled), String(hideTimerCountdown),
         String(cameraEnabled), String(accessoriesEnabled), String(hapticFeedback),
         String(shelfWindow), String(dragReveal), String(appPanel),
         String(hoverExpand), String(hideUntilHover), String(hiddenShowsActivity), String(hideInFullscreen), String(coversMenus),
         display, silhouette, String(hover), hidden, order, String(volume), String(inputSource),
         String(brightness), String(keyboardLight),
         String(microphone), String(battery), String(clipboard), String(clipboardWindow), String(snippetsWindow), clipboardCardSize,
         String(capture), String(trackChange), captureAction, String(showInCaptures),
         String(returnHome), homeModule, String(opensActivity), String(scratchpad),
         String(agentsEnabled), String(watchEnabled), String(keepAwakeActivity), String(shortcutEnabled)]
    }

    var access: Binding<NotchQuickAccessConfiguration> {
        Binding(get: { NotchQuickAccessConfiguration.stored() }, set: { accessData = $0.encoded })
    }

    var orderedModules: [NotchModule] {
        let stored = order.split(separator: ",").compactMap { NotchModule(rawValue: String($0)) }
        var seen = Set<NotchModule>()
        return (stored + NotchSupport.rootModules).filter { seen.insert($0).inserted && NotchSupport.isExploreModule($0) }
    }
}
