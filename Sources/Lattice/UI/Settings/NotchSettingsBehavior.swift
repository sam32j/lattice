import SwiftUI
import EventKit

extension NotchSettings {
    var openingCard: some View {
        let opening = FeatureStrings.notchOpening(l10n.language)
        return SettingsCard(title: opening.opening) {
            HStack(spacing: 8) {
                choice(opening.clickToOpen, symbol: "cursorarrow", selected: !hover) {
                    hideUntilHover = false
                    hover = false
                }
                choice(opening.hoverToOpen, symbol: "cursorarrow.motionlines", selected: hover) {
                    hover = true
                }
            }
            if hover {
                SettingsControlRow(title: opening.actionOnHover) {
                    Picker(opening.actionOnHover, selection: $hoverExpand) {
                        Text(opening.preview).tag(false)
                        Text(opening.expand).tag(true)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                hoverDelayPicker(opening)
                if hoverExpand { closeDelayPicker(opening) }
                SettingsToggleRow(title: opening.hiddenUntilHover,
                                  caption: opening.hiddenUntilHoverHint,
                                  isOn: $hideUntilHover)
                if hideUntilHover {
                    SettingsToggleRow(title: opening.showLiveActivity,
                                      caption: opening.showLiveActivityHint,
                                      isOn: $hiddenShowsActivity)
                }
            }
            SettingsControlRow(title: opening.defaultPage) {
                Picker(opening.defaultPage, selection: Binding(get: {
                    guard returnHome else { return "" }
                    return NotchModule(rawValue: homeModule)?.rawValue
                        ?? NotchReopeningDestination(rawValue: homeModule)?.rawValue
                        ?? NotchModule.controls.rawValue
                }, set: { value in
                    returnHome = !value.isEmpty
                    if returnHome { homeModule = value }
                })) {
                    Text(editor.lastPage).tag("")
                    Text(text.panel).tag(NotchReopeningDestination.appPanel.rawValue)
                    Text(text.sectionsTitle).tag(NotchReopeningDestination.explore.rawValue)
                    ForEach(NotchSupport.modules()) { module in
                        Text(module.title(l10n.language)).tag(module.rawValue)
                    }
                    if let saved = NotchModule(rawValue: homeModule), !NotchSupport.modules().contains(saved) {
                        Text(saved.title(l10n.language)).tag(saved.rawValue).disabled(true)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            SettingsToggleRow(title: opening.openVisibleActivity,
                              caption: opening.openVisibleActivityHint,
                              isOn: $opensActivity)
        }
    }

    var destinationsCard: some View {
        SettingsCard(title: editor.destinations) {
            destination(text.captures, symbol: "photo.stack", value: $capture,
                        available: AppFeature.screenshot.isAvailable || AppFeature.screenRecorder.isAvailable)
        }
    }

    func hoverDelayPicker(_ strings: NotchOpeningStrings) -> some View {
        let binding = Binding<NotchDelayPreset>(
            get: { NotchDelayPreset.closestHoverPreset(for: hoverDelay) },
            set: { hoverDelay = $0.hoverDelay }
        )
        return SettingsControlRow(title: strings.hoverDelay, caption: strings.hoverDelayHint) {
            Picker(strings.hoverDelay, selection: binding) {
                ForEach(NotchDelayPreset.allCases) { preset in
                    Text(preset.title(l10n.language)).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    func closeDelayPicker(_ strings: NotchOpeningStrings) -> some View {
        let binding = Binding<NotchDelayPreset>(
            get: { NotchDelayPreset.closestClosePreset(for: closeDelay) },
            set: { closeDelay = $0.closeDelay }
        )
        return SettingsControlRow(title: strings.closeDelay, caption: strings.closeDelayHint) {
            Picker(strings.closeDelay, selection: binding) {
                ForEach(NotchDelayPreset.allCases) { preset in
                    Text(preset.title(l10n.language)).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    func choice(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 68).padding(8)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1) }
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Each outline in a slice of menu bar, drawn as the island draws it.
    func silhouetteChoice(_ item: NotchSilhouette, title: String) -> some View {
        let selected = (NotchSilhouette(rawValue: silhouette) ?? .capsule) == item
        return Button { silhouette = item.rawValue } label: {
            VStack(spacing: 10) {
                NotchSilhouetteSample(silhouette: item)
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 68).padding(8)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1) }
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    func showModule(_ module: NotchModule) {
        if module == .hub {
            router.request(FeatureSettingsDestination(.launcherGrid))
        } else {
            router.request(FeatureSettingsDestination(.notchWidget(module)))
        }
    }

    /// A control that opens a page is off while that page is hidden, or while
    /// the feature behind it is disabled; the others follow their feature.
    func controlReason(_ item: NotchControlItem) -> String {
        // The keyboard light also needs a keyboard that has one.
        if item == .keyboardLight, AppFeature.brightness.isAvailable { return editor.keyboardLightUnavailable }
        switch item.setupRequirement {
        case .feature(let feature): return feature.enableReason(l10n)
        case .page(let module, let feature): return pageReason(module, feature: feature)
        case .none: return text.disabled
        }
    }

    func controlUnavailableAction(_ item: NotchControlItem) -> (() -> Void)? {
        if item == .keyboardLight, AppFeature.brightness.isAvailable { return nil }
        switch item.setupRequirement {
        case .feature(let feature):
            return { feature.showInFeatures() }
        case .page(let module, let feature):
            return pageAction(module, feature: feature)
        case .none: return nil
        }
    }

    /// The one feature a page needs; Captures and System accept any of several.
    func moduleFeature(_ module: NotchModule) -> AppFeature? {
        switch module {
        case .controls, .music, .captures, .system, .videoDownloader: return nil
        case .mixer: return .mixer
        case .clipboard: return .clipboardHistory
        case .files: return .shelf
        case .hub: return .quickLauncher
        case .calendar: return .notchCalendar
        case .notifications: return .notchNotifications
        case .timer: return .notchTimer
        case .camera: return .cameraPreview
        case .downloads: return .notchDownloads
        case .scratchpad: return .scratchpad
        case .agents: return .notchAgents
        case .watch: return .notchWatch
        case .snippets: return .textSnippets
        }
    }

    func pageReason(_ module: NotchModule, feature: AppFeature?) -> String {
        if let feature, !feature.isAvailable { return feature.enableReason(l10n) }
        return editor.showPage(module.title(l10n.language))
    }

    /// Dedicated controls remain on Content even when uninstalled; other
    /// features lead to their installation row in Features.
    func pageAction(_ module: NotchModule, feature: AppFeature?) -> () -> Void {
        {
            if let feature, !feature.isAvailable, !feature.isManagedOnDedicatedPage { feature.showInFeatures() }
            else { showModule(module) }
        }
    }

    var clipboardFeedbackReason: String {
        let title = FeatureStrings.clipboard(l10n.language).title
        if !AppFeature.clipboardHistory.isAvailable { return AppFeature.clipboardHistory.enableReason(l10n) }
        if !clipboardHistoryEnabled { return editor.enableSetting(FeatureStrings.clipboard(l10n.language).enable) }
        return editor.showPage(title)
    }

    func openClipboardFeedbackSetup() {
        if !AppFeature.clipboardHistory.isAvailable { AppFeature.clipboardHistory.showInFeatures() }
        else if !clipboardHistoryEnabled { router.request(AppFeature.clipboardHistory.settingsDestination) }
        else { showModule(.clipboard) }
    }

    func toggleCard(_ title: String, symbol: String, value: Binding<Bool>, available: Bool, reason: String? = nil,
                            reservesReason: Bool = false, unavailableAction: (() -> Void)? = nil) -> some View {
        NotchEditorItem(symbol: symbol, title: title, included: value, available: available,
                        unavailableReason: available ? nil : reason ?? text.disabled,
                        unavailableAction: unavailableAction, reservesReason: reservesReason) {
            value.wrappedValue.toggle()
        }
    }

    /// What the closed island rests with while it is on, by its own rule. The
    /// island switch stands apart, so with the island off this still shows
    /// what it would rest with. A saved battery reading on a Mac without a
    /// battery rests with nothing.
    var restingChoice: NotchIdleContent {
        let choice = NotchSupport.idleContent()
        return choice == .battery && !PowerSampler.hasInternalBattery ? .none : choice
    }


}
