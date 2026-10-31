import SwiftUI

extension SettingsView {
    @ViewBuilder
    var detail: some View {
        switch router.page {
        case .general:
            if router.destination.sectionAnchor == .panelConfiguration,
               sidebarItems.contains(where: { $0.destination == router.destination }) {
                GeneralToolSettings()
            } else {
                GeneralSettings()
            }
        case .features: GeneralSettings()
        case .textSnippets: TextSnippetsSettings()
        case .cameraPreview: DedicatedUtilitySettings(feature: .cameraPreview)
        case .diskImageInstaller: DedicatedUtilitySettings(feature: .diskImageInstaller)
        case .launcherGrid: DedicatedUtilitySettings(feature: .quickLauncher)
        case .notch: NotchSettings().id("notch")
        case .notchWidget(let module): NotchSettings(initialContent: .module(module)).id(module)
        case .notchCompanion: NotchSettings(initialContent: .companion).id("companion")
        case .notchMascot: NotchMascotSettings()
        case .radialMenu: FeatureConfigurationPage(feature: .radialMenu) { RadialMenuSettings() }
        case .commandBar: FeatureConfigurationPage(feature: .commandBar) { CommandBarSettings() }
        case .energy: DisplaySettings(focus: router.destination.sectionAnchor)
        case .monitor: MonitorSettings()
        case .mouse: MouseSettings()
        case .switcher: SwitcherSettings()
        case .dock: DockSettings()
        case .keyboard: KeyboardSettings()
        case .wallpaper: DisplaySettings(focus: .wallpaper)
        case .uninstaller: FeatureActivationPage(feature: .uninstaller) { UninstallerView() }
        case .killProcess:
            FeatureActivationPage(feature: .killProcess,
                                  options: { AnyView(KillProcessOptions().frame(width: 330)) }) {
                KillProcessView()
            }
        case .portManager: FeatureActivationPage(feature: .portManager) { PortManagerView() }
        case .urlCleaner: URLCleanerSettings()
        case .cleaner: FeatureActivationPage(feature: .cleaner) { CleanerView() }
        case .homebrew: FeatureActivationPage(feature: .homebrew) { HomebrewSettings() }
        case .appUpdates:
            FeatureActivationPage(feature: .appUpdates,
                                  options: { AnyView(AppUpdatesOptions().frame(width: 380, height: 420)) }) {
                AppUpdatesSettings()
            }
        case .media: FeatureActivationPage(feature: .mediaTools) { MediaSettings() }
        case .videoDownloader: VideoDownloaderSettings()
        case .clipboard: ClipboardSettings()
        case .audioInput: AudioInputSettings()
        case .audioOutput: AudioOutputSettings()
        case .scratchpad: ScratchpadSettings()
        case .screenshot: ScreenshotSettings()
        case .screenRecorder: ScreenRecorderSettings()
        case .windowLayout: WindowLayoutSettings()
        case .shelf: ShelfSettings()
        case .shortcuts: ShortcutsSettings()
        case .dataPermissions: DataPermissionsSettings()
        case .about: AboutSettings()
        }
    }
}
