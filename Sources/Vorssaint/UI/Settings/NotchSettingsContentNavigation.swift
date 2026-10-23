import SwiftUI
import EventKit

extension NotchSettings {
    var layoutPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            NotchLayoutEditor(configuration: access, size: $size, width: $customWidth, height: $customHeight) {
                showModule(.controls)
            }
            SettingsCard(title: text.size) {
                HStack(spacing: 10) {
                    choice(text.compact, symbol: "rectangle.compress.vertical", selected: size == NotchSize.compact.rawValue) { size = NotchSize.compact.rawValue }
                    choice(text.spacious, symbol: "rectangle.expand.vertical", selected: size == NotchSize.spacious.rawValue) { size = NotchSize.spacious.rawValue }
                    choice(text.custom, symbol: "arrow.up.left.and.arrow.down.right", selected: size == NotchSize.custom.rawValue) { size = NotchSize.custom.rawValue }
                }
                if size == NotchSize.custom.rawValue {
                    // One grid starts both sliders at the same edge in every language.
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        dimensionSlider(text.width, value: $customWidth, range: NotchSize.widthRange, fallback: NotchSize.defaultWidth)
                        dimensionSlider(text.maximumHeight, value: $customHeight, range: NotchSize.heightRange, fallback: NotchSize.defaultHeight)
                    }
                    Text(text.sizeHint).font(.caption).foregroundStyle(.secondary)
                }

            }
            // Only a display without a camera can float the island.
            if NotchSupport.hasDisplayWithoutNotch {
                SettingsCard(title: text.withoutNotch) {
                    HStack(spacing: 10) {
                        silhouetteChoice(.capsule, title: text.capsuleShape)
                        silhouetteChoice(.notch, title: text.notchShape)
                    }
                    // An island kept on a camera, or away with the lid closed,
                    // shows neither shape, so the card says where to change that.
                    if enabled, !NotchService.reachesDisplayWithoutNotch(NotchDisplay(rawValue: display) ?? .automatic) {
                        Text(text.withoutNotchUnreached).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(text.showOnAllDisplays) { display = NotchDisplay.all.rawValue }
                    }
                }
                if NotchSilhouette(rawValue: silhouette) ?? .capsule == .capsule {
                    SettingsCard(title: text.capsuleFit) {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                            // Even widths keep the capsule centred on whole points.
                            fitSlider(text.width, card: text.capsuleFit, value: $capsuleFitWidth,
                                      range: NotchCapsuleFit.widthRange, step: 2)
                            fitSlider(text.height, card: text.capsuleFit, value: $capsuleFitHeight,
                                      range: NotchCapsuleFit.heightRange, step: 1)
                            fitSlider(text.fromTop, card: text.capsuleFit, value: $capsuleFitDrop,
                                      range: NotchCapsuleFit.dropRange, step: 1)
                        }
                        Text(text.capsuleFitHint).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            SettingsCard {
                switchRow("capsule", text.showOutline, isOn: $outlineEnabled)
            }
            // Only a physical camera has an outline to match.
            if NotchSupport.hasNotchedDisplay {
                SettingsCard(title: text.cameraFit) {
                    switchRow("rectangle.topthird.inset.filled", text.hideMenuBarGap,
                              caption: text.hideMenuBarGapHint, isOn: $hideMenuBarGap)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        // Whole points keep the island centred on the camera's pixels.
                        fitSlider(text.width, card: text.cameraFit, value: $cameraFitWidth,
                                  range: NotchCameraFit.widthRange, step: 1)
                        fitSlider(text.height, card: text.cameraFit, value: $cameraFitHeight,
                                  range: NotchCameraFit.heightRange, step: 0.5)
                    }
                    Text(text.cameraFitHint).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }


    var moduleDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(title: selectedModule.title(l10n.language)) {
                    PermissionGatedSettingsRow(title: SettingsContentStrings.enable(selectedModule.title(l10n.language), language: l10n.language),
                                      isOn: moduleEnableBinding(selectedModule),
                                      requiring: moduleFeature(selectedModule)?.activationPermissions ?? [])
                    if selectedModule == .captures || selectedModule == .system {
                        Divider()
                        ForEach(contentFeatures(selectedModule), id: \.self) { feature in
                            PermissionGatedSettingsRow(title: feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)),
                                              isOn: contentFeatureBinding(feature), requiring: feature.activationPermissions)
                        }
                    }
                }
                NotchIslandPreview(module: selectedModule, hidden: !isShown(selectedModule))
                    .frame(height: 280)
                if hasOptions(selectedModule) {
                    SettingsCard { moduleOptions(selectedModule) }
                        .disabled(!isShown(selectedModule))
                        .opacity(isShown(selectedModule) ? 1 : 0.55)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)
        }
        .frame(minHeight: 0, maxHeight: .infinity)
        .id(selectedModule)
    }

    var sectionList: some View {
        SettingsCard {
            ForEach(orderedModules) { module in
                PanelReorderableItem(item: module,
                    order: Binding(get: { orderedModules }, set: { order = $0.map(\.rawValue).joined(separator: ",") }),
                    dragging: $draggingModule) {
                    NotchContentNavigationRow(symbol: module.symbol, title: module.title(l10n.language),
                                              enabled: isShown(module), language: l10n.language) {
                        showModule(module)
                    }
                    .contextMenu {
                        Button(FeatureStrings.clipboard(l10n.language).moveUp) { moveModule(module, by: -1) }
                            .disabled(orderedModules.first == module)
                        Button(FeatureStrings.clipboard(l10n.language).moveDown) { moveModule(module, by: 1) }
                            .disabled(orderedModules.last == module)
                    }
                    .accessibilityAction(named: FeatureStrings.clipboard(l10n.language).moveUp) { moveModule(module, by: -1) }
                    .accessibilityAction(named: FeatureStrings.clipboard(l10n.language).moveDown) { moveModule(module, by: 1) }
                }
            }
            NotchContentNavigationRow(symbol: AppFeature.notchMascot.symbolName,
                                      title: FeatureStrings.notchMascot(l10n.language).title,
                                      enabled: mascotEnabled && features.isAvailable(.notchMascot),
                                      language: l10n.language) {
                contentSelection = .companion
            }
        }
    }

    func moduleEnableBinding(_ module: NotchModule) -> Binding<Bool> {
        Binding(get: { moduleBinding(module).wrappedValue && (moduleFeature(module) == nil || module.isAvailable()) }, set: { enabled in
            let ownedFeatures: [AppFeature]
            if let feature = moduleFeature(module) {
                ownedFeatures = [feature]
            } else {
                ownedFeatures = []
            }
            if !ownedFeatures.isEmpty {
                for feature in ownedFeatures {
                    if AppFeature.dynamicIslandExtensions.contains(feature) {
                        FeatureRuntime.shared.setIslandFeature(feature, enabled: enabled)
                    } else if let key = feature.enabledKeys.first {
                        UserDefaults.standard.set(enabled, forKey: key)
                    }
                }
                if module == .mixer { UserDefaults.standard.set(enabled, forKey: DefaultsKey.volumeMixerEnabled) }
                FeatureRuntime.shared.setAvailable(ownedFeatures, enabled)
                FeatureRuntime.shared.sync(ownedFeatures)
            }
            moduleBinding(module).wrappedValue = enabled
            sync()
        })
    }

    func moveModule(_ module: NotchModule, by offset: Int) {
        var modules = orderedModules
        guard let index = modules.firstIndex(of: module), modules.indices.contains(index + offset) else { return }
        modules.swapAt(index, index + offset)
        order = modules.map(\.rawValue).joined(separator: ",")
    }

    func contentFeatures(_ module: NotchModule) -> [AppFeature] {
        module == .captures ? [.screenshot, .screenRecorder] :
            [.monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork,
             .monitorDisk, .monitorPower, .fanControl, .connectedDevices]
    }

    func contentFeatureBinding(_ feature: AppFeature) -> Binding<Bool> {
        Binding(get: { feature.isAvailable }, set: { enabled in
            for key in feature.enabledKeys { UserDefaults.standard.set(enabled, forKey: key) }
            if feature == .screenshot { UserDefaults.standard.set(enabled, forKey: DefaultsKey.screenshotEnabled) }
            if feature == .screenRecorder { UserDefaults.standard.set(enabled, forKey: DefaultsKey.screenRecorderEnabled) }
            FeatureRuntime.shared.setAvailable([feature], enabled)
            FeatureRuntime.shared.sync([feature])
            sync()
        })
    }

    func isShown(_ module: NotchModule) -> Bool {
        module.isAvailable() && moduleBinding(module).wrappedValue
    }

    /// The mixer, the system page and the tools arrange themselves in the island.
    func hasOptions(_ module: NotchModule) -> Bool {
        ![.mixer, .system, .tools].contains(module)
    }


}
