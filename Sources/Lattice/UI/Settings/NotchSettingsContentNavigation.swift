import SwiftUI
import EventKit

extension NotchSettings {
    var layoutPage: some View {
        SettingsCard {
            SettingsRow(symbol: "sparkles", title: "Quick Actions", caption: "Quick action buttons around your Dynamic Island.") {
                Button(FeatureStrings.screenshot(l10n.language).editButton) {
                    NotchLiveQuickActionsEditorController.shared.show()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var displayCompatibilityCheck: some View {
        if enabled, !NotchService.reachesDisplayWithoutNotch(NotchDisplay(rawValue: display) ?? .automatic) {
            Button(text.showOnAllDisplays) { display = NotchDisplay.all.rawValue }
        }
    }

    @ViewBuilder
    func contentDetailView(selection: NotchContentDestination) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                if router.canGoBack(isPageVisible: isPageVisible) {
                    router.goBack(isPageVisible: isPageVisible)
                } else {
                    router.request(FeatureSettingsDestination(.notch))
                }
            } label: {
                Label(FeatureStrings.notch(l10n.language).title, systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            if selection == .companion {
                NotchMascotSettings(embedded: true)
                    .frame(minHeight: 0, maxHeight: .infinity)
            } else {
                moduleDetail
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .padding(22)
        .clipped()
    }

    private func isPageVisible(_ page: SettingsPage) -> Bool {
        FeatureVisibilitySupport.isPageVisible(page, isAvailable: { $0.isAvailable })
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
                router.request(FeatureSettingsDestination(.notchCompanion))
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
            for feature in ownedFeatures where AppFeature.dynamicIslandExtensions.contains(feature) {
                FeatureRuntime.shared.setIslandFeature(feature, enabled: enabled)
            }
            if enabled, let feature = ownedFeatures.first,
               !AppFeature.dynamicIslandExtensions.contains(feature), !feature.isAvailable {
                feature.showInFeatures()
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
        ![.mixer, .system, .hub].contains(module)
    }


}
