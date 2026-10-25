import SwiftUI
import EventKit

extension NotchSettings {
    var behaviorPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: editor.opening) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    choice(editor.clickOpen, symbol: "cursorarrow", selected: !hover) { hideUntilHover = false; hover = false }
                    choice(editor.hoverPreview, symbol: "rectangle.topthird.inset.filled", selected: hover && !hoverExpand && !hideUntilHover) { hideUntilHover = false; hover = true; hoverExpand = false }
                    choice(editor.hoverExpand, symbol: "arrow.up.left.and.arrow.down.right", selected: hover && hoverExpand && !hideUntilHover) { hideUntilHover = false; hover = true; hoverExpand = true }
                    choice(editor.hiddenUntilHover, symbol: "eye.slash", selected: hover && hideUntilHover) { hover = true; hoverExpand = true; hideUntilHover = true }
                }
                if hover && hideUntilHover {
                    switchRow("sparkles", editor.hiddenShowsActivity,
                              caption: hiddenShowsActivity ? editor.hiddenShowsActivityHint : nil,
                              isOn: $hiddenShowsActivity)
                }
                if hover {
                    hoverDelayControl
                    if hoverExpand { closeDelayControl }
                }
                switchRow("keyboard", l10n.s.globalHotkeySection, isOn: $shortcutEnabled)
                if shortcutEnabled {
                    ShortcutPreferenceRow(role: .notch) {
                        NotchService.shared.syncWithPreferences()
                    }
                    .padding(.leading, settingsRowTextInset)
                    if notch.shortcutRegistrationFailed {
                        Text(l10n.s.shortcutUnavailable)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.leading, settingsRowTextInset)
                    }
                }
                switchRow("hand.draw", FeatureStrings.notchGestures(l10n.language).title,
                                         caption: gesturesEnabled ? FeatureStrings.notchGestures(l10n.language).hint : nil,
                          isOn: islandFeatureBinding(.notchGestures, value: $gesturesEnabled))
                switchRow("waveform.path", text.hapticFeedback, isOn: $hapticFeedback)
                SettingsRow(symbol: "arrow.uturn.backward", title: editor.reopening) {
                    Picker(editor.reopening, selection: Binding(get: {
                        guard returnHome else { return "" }
                        return NotchModule(rawValue: homeModule) != nil
                            || NotchReopeningDestination(rawValue: homeModule) != nil
                            ? homeModule : NotchModule.controls.rawValue
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
                            Text(saved.title(l10n.language)).tag(homeModule).disabled(true)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                switchRow("livephoto", editor.openActivity, caption: editor.openActivityHint, isOn: $opensActivity)
            }
            SettingsCard(title: text.display) {
                switchRow("arrow.up.left.and.arrow.down.right", text.hideInFullscreen, isOn: $hideInFullscreen)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    // A mode this version no longer offers is treated as automatic, as the island does.
                    choice(text.automatic, symbol: "display.2",
                           selected: (NotchDisplay(rawValue: display) ?? .automatic) == .automatic) { display = NotchDisplay.automatic.rawValue }
                    choice(text.builtIn, symbol: "laptopcomputer", selected: display == NotchDisplay.builtIn.rawValue) { display = NotchDisplay.builtIn.rawValue }
                    choice(text.mainDisplay, symbol: "display", selected: display == NotchDisplay.main.rawValue) { display = NotchDisplay.main.rawValue }
                    choice(text.followPointer, symbol: "cursorarrow.motionlines",
                           selected: display == NotchDisplay.pointer.rawValue) { display = NotchDisplay.pointer.rawValue }
                    choice(text.allDisplays, symbol: "rectangle.on.rectangle",
                           selected: display == NotchDisplay.all.rawValue) { display = NotchDisplay.all.rawValue }
                }
            }
            SettingsCard(title: editor.destinations) {
                destination(text.captures, symbol: "camera.viewfinder", value: $capture,
                            available: AppFeature.screenshot.isAvailable || AppFeature.screenRecorder.isAvailable)
            }
            SettingsCard(title: editor.privacy) {
                switchRow("camera.viewfinder", text.showInCaptures, isOn: $showInCaptures)
            }
        }
    }

    /// The resting charge can turn red once it runs low, and amber a little
    /// earlier, at levels the person picks.
    @ViewBuilder var lowBatteryControls: some View {
        let strings = NotchLowBatteryStrings.localized(l10n.language)
        switchRow("battery.25percent", strings.title, caption: strings.caption, isOn: $lowBatteryTint)
        if lowBatteryTint {
            let red = NotchSupport.sanitizedLowBatteryThreshold(lowBatteryThreshold)
            levelSlider(strings.threshold, range: NotchSupport.batteryLevelScale,
                        value: Binding(get: { red },
                                       set: {
                                           lowBatteryThreshold = NotchSupport.sanitizedLowBatteryThreshold($0)
                                           // Raising red past amber carries amber along above it.
                                           earlyBatteryThreshold = NotchSupport.earlyBatteryThreshold(earlyBatteryThreshold,
                                                                                                     above: lowBatteryThreshold)
                                       }))
            switchRow("battery.50percent", strings.early, caption: strings.earlyCaption, isOn: $earlyBatteryWarning)
            if earlyBatteryWarning {
                // Both sliders share one fixed scale; amber stops just above red.
                levelSlider(strings.earlyThreshold, range: NotchSupport.batteryLevelScale,
                            value: Binding(get: { NotchSupport.earlyBatteryThreshold(earlyBatteryThreshold, above: red) },
                                           set: { earlyBatteryThreshold = NotchSupport.earlyBatteryThreshold($0, above: red) }))
            }
            switchRow("menubar.rectangle", strings.menuBar, isOn: $lowBatteryMenuBar)
        }
    }

    func levelSlider(_ title: String, range: ClosedRange<Int>, value: Binding<Int>) -> some View {
        let formatted = "\(value.wrappedValue)%"
        let slider = Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) })
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(formatted).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: slider, in: Double(range.lowerBound)...Double(range.upperBound), step: 1) {
                Text(title)
            }.labelsHidden().accessibilityValue(formatted)
        }.padding(.leading, settingsRowTextInset)
    }

    var hoverDelayControl: some View {
        delayControl(editor.activationTime, hint: editor.activationTimeHint, value: $hoverDelay,
                     range: NotchSupport.hoverDelayRange, sanitize: NotchSupport.sanitizedHoverDelay)
    }

    var closeDelayControl: some View {
        delayControl(editor.closeTime, hint: editor.closeTimeHint, value: $closeDelay,
                     range: NotchSupport.closeDelayRange, sanitize: NotchSupport.sanitizedCloseDelay)
    }

    func delayControl(_ title: String, hint: String, value stored: Binding<Double>,
                              range: ClosedRange<Double>, sanitize: @escaping (Double) -> Double) -> some View {
        let value = Binding(get: { sanitize(stored.wrappedValue) }, set: { stored.wrappedValue = sanitize($0) })
        let formatted = String(format: editor.activationTimeFormat, locale: Locale(identifier: l10n.language.rawValue), value.wrappedValue)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(formatted).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.05) {
                Text(title)
            }.labelsHidden().accessibilityValue(formatted)
            Text(hint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        selectedModule = module
        contentSelection = .module(module)
        tab = .content
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
        case .controls, .music, .captures, .system: return nil
        case .mixer: return .mixer
        case .clipboard: return .clipboardHistory
        case .files: return .shelf
        case .tools: return .quickLauncher
        case .calendar: return .notchCalendar
        case .notifications: return .notchNotifications
        case .timer: return .notchTimer
        case .camera: return .cameraPreview
        case .downloads: return .notchDownloads
        case .scratchpad: return .scratchpad
        case .agents: return .notchAgents
        case .watch: return .notchWatch
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
