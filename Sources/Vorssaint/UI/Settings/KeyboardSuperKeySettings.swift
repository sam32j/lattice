import SwiftUI

extension KeyboardSettings {
    // MARK: - Super Key Card

    var superKeyStatus: SettingsFeatureStatus {
        func message(_ key: InputSettingsStrings.Key) -> String { InputSettingsStrings.text(key, l10n.language) }
        guard superKeyEnabled else { return SettingsFeatureStatus(color: .secondary, message: message(.off)) }
        if let failure = superKey.mappingFailure {
            return SettingsFeatureStatus(color: failure == .foreignMapping ? .red : .secondary,
                                         message: failure == .foreignMapping ? message(.superKeyConflict) : text.mappingFailure(failure))
        }
        if !permissions.accessibility {
            return SettingsFeatureStatus(color: .secondary, message: message(.permissionRequired))
        }
        if superKey.isPausedForApplication {
            return SettingsFeatureStatus(color: .secondary, message: FeatureStrings.mouseExceptions(l10n.language).pausedSuperKey)
        }
        return SettingsFeatureStatus(color: superKey.isRunning ? .green : .secondary,
                                     message: message(superKey.isRunning ? .superKeyActive : .waiting))
    }

    var superKeyOptionsDisabled: Bool {
        !superKeyEnabled || superKeyStatus.color == .red
    }

    var superKeyCard: some View {
        SettingsCard(title: text.pageTitle) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(symbol: "keyboard", title: InputSettingsStrings.text(.enableSuperKey, l10n.language), caption: text.enableCaption) {
                    PermissionGatedToggle(InputSettingsStrings.text(.enableSuperKey, l10n.language), isOn: $superKeyEnabled)
                        .labelsHidden()
                        .onChange(of: superKeyEnabled) { _, value in
                            superKey.syncWithPreferences()
                            features.finishAvailabilityChange()
                            guard value, !permissions.accessibility else { return }
                            permissions.requestAccessibility()
                            permissions.openAccessibilitySettings()
                        }
                }

                if superKeyEnabled {
                HStack(spacing: 6) {
                    Text(InputSettingsStrings.text(.superKey, l10n.language))
                    Spacer(minLength: 12)
                    SettingsStatusDot(status: superKeyStatus)
                    Picker(InputSettingsStrings.text(.superKey, l10n.language), selection: sourceBinding) {
                        ForEach(SuperKeySource.allCases) { source in
                            Text(text.sourceLabel(source)).tag(source)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu)
                    .fixedSize()
                    .disabled(!superKeyEnabled)
                }
                .padding(.leading, settingsRowTextInset)

                diagram

                SettingsControlRow(title: text.soloSection) {
                    Picker(text.soloSection, selection: soloBinding) {
                        Text(text.soloNothing).tag(SuperKeySoloAction.none)
                        Text(text.soloCapsLock).tag(SuperKeySoloAction.capsLock)
                        Text(text.soloInputSource).tag(SuperKeySoloAction.inputSource)
                        Text(text.soloEscape).tag(SuperKeySoloAction.escape)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220, alignment: .trailing)
                }
                .padding(.leading, settingsRowTextInset)
                .help(text.soloCaption)
                .disabled(superKeyOptionsDisabled)

                MouseExceptionsList(scope: .superKey)
                    .padding(.leading, settingsRowTextInset)
                    .disabled(superKeyOptionsDisabled)
                }
            }
        }
    }

    var diagram: some View {
        HStack(spacing: 10) {
            VStack(spacing: 3) {
                keyCap(text.sourceLabel(source), symbol: source == .capsLock ? "capslock" : nil, wide: true)
                Text(text.holdHint).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                .padding(.bottom, 14)
            HStack(spacing: 5) {
                ForEach(modifierChoices) { modifierKeyCap($0) }
            }
            .padding(.bottom, 14)
        }
        .opacity(superKeyOptionsDisabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.18), value: superKeyOptionsDisabled)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    func keyCap(_ title: String, symbol: String?, wide: Bool) -> some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .frame(minWidth: wide ? 84 : 30, minHeight: 30)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
    }

    func modifierKeyCap(_ choice: ModifierChoice) -> some View {
        let selected = selectedModifiers.contains(choice.modifier)
        return Button {
            toggleModifier(choice.modifier)
        } label: {
            Text(choice.symbol).font(.system(size: 12, weight: .medium)).frame(minWidth: 30, minHeight: 30)
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(selected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(superKeyOptionsDisabled || (selected && !canRemoveModifier(choice.modifier)))
        .help(choice.name)
        .accessibilityLabel(choice.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    var selectedModifiers: GlobalShortcutModifiers { SuperKeySupport.modifiers(from: modifierStorage) }
    var source: SuperKeySource { SuperKeySource.sanitized(sourceRaw) }

    var sourceBinding: Binding<SuperKeySource> {
        Binding { source } set: { source in
            sourceRaw = source.rawValue
            superKey.syncWithPreferences()
        }
    }

    func toggleModifier(_ modifier: GlobalShortcutModifiers) {
        var next = selectedModifiers
        if next.contains(modifier) { next.remove(modifier) } else { next.insert(modifier) }
        guard next.hasPrimaryModifier else { return }
        modifierStorage = SuperKeySupport.storageValue(for: next)
        superKey.syncWithPreferences()
    }

    func canRemoveModifier(_ modifier: GlobalShortcutModifiers) -> Bool {
        var remaining = selectedModifiers
        remaining.remove(modifier)
        return remaining.hasPrimaryModifier
    }

    var soloBinding: Binding<SuperKeySoloAction> {
        Binding {
            SuperKeySoloAction.sanitized(soloActionRaw)
        } set: { action in
            soloActionRaw = action.rawValue
            superKey.syncWithPreferences()
        }
    }

}
