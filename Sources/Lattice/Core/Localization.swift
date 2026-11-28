// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The way a language agrees a noun with the number in front of it.
enum CountAgreement {
    /// One form for exactly one, another for every other count.
    case oneAndMany
    /// Russian and Ukrainian: the number's last digits decide. 21 takes the
    /// first form and 22 the middle one, while 11 through 14 fall back to the last.
    case byLastDigits
    /// Slovak: the whole number decides. Only one itself takes the first form
    /// and only two through four the middle one, so 21 and 22 read
    /// "21 súborov" and "22 súborov" the same way 25 does.
    case byWholeNumber
}

/// Languages the interface can use. The first launch defaults to the system
/// language; Settings lets the user override it at any time.
enum AppLanguage: String, CaseIterable, Identifiable {
    case enUS = "en-US"
    case ptBR = "pt-BR"
    case tr = "tr"
    case ru = "ru"
    case es = "es"
    case sk = "sk"
    case de = "de"
    case fr = "fr"
    case it = "it"
    case ja = "ja"
    case ko = "ko"
    case uk = "uk"
    case zhHans = "zh-Hans"
    case zhTW = "zh-TW"
    case zhHK = "zh-HK"

    var id: String { rawValue }

    /// How this language agrees a counted noun with the number in front of
    /// it. Three of the fifteen put a distinct form between one and many, and
    /// they disagree on which numbers take it, so the count itself is not
    /// enough to pick a form without knowing the language's rule.
    var countAgreement: CountAgreement {
        switch self {
        case .ru, .uk: return .byLastDigits
        case .sk: return .byWholeNumber
        default: return .oneAndMany
        }
    }

    /// The language's own name, shown in its own script, the way macOS lists them.
    var displayName: String {
        switch self {
        case .enUS: return "English (US)"
        case .ptBR: return "Português (Brasil)"
        case .tr: return "Türkçe"
        case .ru: return "Русский"
        case .es: return "Español"
        case .sk: return "Slovenčina"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zhHans: return "简体中文"
        case .zhHK: return "繁體中文（香港）"
        case .zhTW: return "繁體中文（台灣）"
        case .uk: return "Українська"
        }
    }

    /// Dates and times in this language, arranged the way System Settings
    /// asks: region, 12- or 24-hour clock and first day of the week. A locale
    /// made from the language alone would bring that language's own clock.
    func formattingLocale(system: Locale = .autoupdatingCurrent) -> Locale {
        var components = Locale.Components(identifier: rawValue)
        components.region = system.region
        components.hourCycle = system.hourCycle
        components.firstDayOfWeek = system.firstDayOfWeek
        return Locale(components: components)
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let p = preferred.lowercased()

        if p.hasPrefix("zh-hk") || p.hasPrefix("zh-hant-hk") {
            return .zhHK
        }

        if p.hasPrefix("zh-tw") || p.hasPrefix("zh-hant-tw") || p.hasPrefix("zh-hant") {
            return .zhTW
        }

        let matches: [(String, AppLanguage)] = [
            ("pt", .ptBR), ("tr", .tr), ("ru", .ru), ("es", .es), ("sk", .sk), ("de", .de),
            ("fr", .fr), ("it", .it), ("ja", .ja), ("ko", .ko), ("uk", .uk), ("zh", .zhHans),
        ]
        for (prefix, language) in matches where preferred.hasPrefix(prefix) { return language }
        return .enUS
    }
}

/// Source of every user-facing string. Views observe this object so the whole
/// interface re-renders immediately when the language changes.
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: DefaultsKey.language) }
    }

    var s: Strings { Strings.localized(language) }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.language),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .systemDefault
        }
    }
}

extension Strings {
    /// The catalog for a language other than the current one, as the
    /// feature string tables offer theirs.
    static func localized(_ language: AppLanguage) -> Strings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhHK: return .zhHK
        case .zhTW: return .zhTW
        case .uk: return .uk
        }
    }
}

/// Flat, compiler-checked catalog of UI strings. Adding a field here forces
/// both translations to be provided.
struct Strings {
    // MARK: Menu bar & context menu
    let menuEnableAwake: String
    let menuDisableAwake: String
    let menuSettings: String
    let menuAbout: String
    let menuQuit: String
    // Standard application menu bar (App / Edit / Window) shown while one of the
    // app's own windows is focused. Without it, an accessory app has no main menu
    // and the standard shortcuts (Cmd+H/M/W/Q, Cmd+C/V/X/A) do nothing.
    let menuHide: String
    let menuHideOthers: String
    let menuShowAll: String
    let menuEdit: String
    let menuUndo: String
    let menuRedo: String
    /// Named actions an icon-only control borrows so it can say what it
    /// does. No feature owns these, because half a dozen already share them.
    let actionClear: String
    let actionMute: String
    let actionUnmute: String
    let actionPause: String
    let menuCut: String
    let menuCopy: String
    let menuPaste: String
    let menuSelectAll: String
    let menuWindow: String
    let menuMinimize: String
    let menuZoom: String
    let menuClose: String

    // MARK: Durations
    let minutes15: String
    let minutes30: String
    let hour1: String
    let hours2: String
    let hours4: String
    let hours8: String
    let indefinitely: String
    let indefinite: String

    // MARK: Panel — header & footer
    let panelQuit: String

    // MARK: Panel — keep awake card
    let keepAwakeTitle: String
    let keepAwakeEndsIn: String        // + remaining
    let keepAwakeUntilDisabled: String

    // MARK: Panel — system monitor
    let temperatures: String
    let cpuLabel: String
    let gpuLabel: String
    let batteryLabel: String
    let memorySection: String
    let memoryPressure: String
    let memorySwapUsed: String
    let memoryCompressed: String
    let memoryCachedFiles: String
    let pressureNormal: String
    let pressureWarning: String
    let pressureCritical: String
    let monitorUnavailable: String
    let energyAppsIdle: String

    // MARK: Notifications
    let notifySessionEndedTitle: String
    let notifySessionEndedBody: String
    let notifyBatteryTitle: String
    let notifyBatteryBody: String

    // MARK: Administrator prompts (shown by macOS password dialogs)
    let adminPromptClamshellOff: String
    let adminPromptRecover: String
    let adminPromptUpdate: String
    let adminPromptSudoersInstall: String
    let adminPromptSudoersRemove: String

    // MARK: Settings — window & tabs
    let settingsTitle: String
    let tabGeneral: String
    let tabEnergy: String
    let tabMouse: String
    let tabSwitcher: String
    let tabAbout: String
    let tabReleaseNotes: String
    let minimalWindowPreviews: String
    let minimalWindowPreviewsCaption: String
    let previewSizeLabel: String
    let previewSizeNormal: String
    let previewSizeLarge: String
    let previewSizeXLarge: String

    // MARK: Settings — advanced
    let advancedClearButton: String
    let advancedClearFailed: String
    let advancedUninstallDescription: String
    let advancedUninstallButton: String
    let advancedUninstallConfirmTitle: String
    let advancedUninstallConfirmBody: String
    let advancedUninstallFailedTitle: String
    let advancedUninstallFailedBody: String

    // MARK: Settings — general
    let launchAtLogin: String
    let languageLabel: String
    let hotkeyToggle: String

    // MARK: Settings — energy
    let batteryNever: String
    let configuring: String
    let sudoersFailed: String

    // MARK: Settings — mouse
    let invertMouseScroll: String
    let scrollTrackpadNote: String
    let smoothScrollName: String
    let smoothScrollCaption: String
    let smoothScrollStepLabel: String
    let mouseNavigationEnable: String
    let middleClickSection: String
    let middleClickEnable: String
    let middleClickEnableCaption: String
    let middleClickNoTrackpad: String
    let middleClickTapPicker: String
    let middleClickTapOff: String
    let middleClickTapThreeFingers: String
    let middleClickTapFourFingers: String
    let middleClickTapCaption: String
    let ocrName: String
    let ocrCaption: String
    let ocrCopied: String
    let ocrNoText: String
    let colorPickerName: String
    let colorPickerCaption: String
    let micMuteName: String
    let micUnmuteName: String
    let micMuteCaption: String
    let micMuteFollowCallAppsToggle: String
    let micMuteFollowCallAppsCaption: String
    let micMutedHUD: String
    let micUnmutedHUD: String
    let micMutePartialHUD: String
    let micUnmutePartialHUD: String
    let micMuteMenuBarToggle: String
    let pastePlainName: String
    let pastePlainCaption: String
    let launcherName: String

    // MARK: Settings — switcher
    let switcherSection: String
    let switcherNoWindows: String
    let switcherIconRowMode: String
    let switcherIconRowModeCaption: String
    let switcherSimpleModeCaption: String
    let switcherShortcutHintApps: String
    let switcherShortcutHintWindows: String
    let switcherAppearanceDelay: String
    let switcherAppearanceDelayCaption: String
    let switcherMaxColumns: String
    let switcherMaxColumnsCaption: String
    let switcherMaxColumnsAuto: String
    let switcherInstantSelection: String
    let switcherIgnoreHoverSelection: String
    let switcherMergeTabs: String
    let switcherMergeTabsCaption: String
    let switcherWindowlessApps: String
    let switcherWindowlessAppsFinder: String
    let switcherNoOpenWindow: String
    let switcherOtherDesktop: String
    let dockPreviewName: String
    let dockPreviewEnable: String
    let dockPreviewCurrentSpaceOnly: String
    let dockPreviewCurrentSpaceOnlyCaption: String
    let dockPreviewCurrentSpaceOnlyInfo: String
    let dockPreviewBackgroundOpacity: String
    let dockPreviewBackgroundOpacityCaption: String
    let dockPreviewBackgroundOpacityGlassCaption: String
    let dockPreviewOpenDelay: String
    let dockPreviewOpenDelayCaption: String
    let dockPreviewDelayDefault: String
    let dockPreviewDelayLonger: String
    let dockPreviewQuitApplication: String
    let dockPreviewKeepDockVisible: String
    let dockPreviewKeepDockVisibleCaption: String
    let dockPreviewOrderByCreation: String
    let dockPreviewOrderByCreationCaption: String
    let dockClickMinimize: String
    let dockClickCycleWindows: String
    let dockPreviewDockUnavailable: String
    let dockPreviewOpenWindow: String
    let dockPreviewCloseWindow: String
    let dockPreviewMinimizeWindow: String
    let dockPreviewRestoreWindow: String
    let dockPreviewPinPanel: String
    let dockPreviewUnpinPanel: String
    let dockPreviewPinned: String
    let dockPreviewClosePanel: String
    let dockPreviewPreviousWindow: String
    let dockPreviewNextWindow: String

    // MARK: Finder automation
    let finderAutomationNote: String

    // MARK: Feature — quit on last window close
    let autoQuitName: String
    let autoQuitEnable: String
    let autoQuitEnableCaption: String
    let autoQuitExceptionsTitle: String

    // MARK: Feature — complete app uninstaller
    let uninstallerName: String
    let uninstallerChoose: String
    let uninstallerPickerTitle: String
    let uninstallerPickerSearch: String
    let uninstallerPickerEmpty: String
    let uninstallerFDANote: String
    let uninstallerFDAGrant: String
    let uninstallerFDAHint: String
    let uninstallerFDARelaunch: String
    let uninstallerScanning: String
    let uninstallerRemoving: String
    let uninstallerFoundTitle: String
    let uninstallerSelectedFormat: String   // + selected, total
    let uninstallerSelectAll: String
    let uninstallerRemove: String
    let uninstallerCancel: String
    let uninstallerConfirmationExpired: String
    let uninstallerDoneTitle: String
    let uninstallerFreedFormat: String      // + size string
    let uninstallerSomeFailed: String
    let uninstallerFailedNeedsFDA: String
    let uninstallerFailedMoreFormat: String
    let uninstallerAnother: String
    let uninstallerCatApp: String
    let uninstallerCatSupport: String
    let uninstallerCatCaches: String
    let uninstallerCatPreferences: String
    let uninstallerCatContainers: String
    let uninstallerCatLogs: String
    let uninstallerCatState: String
    let uninstallerCatOther: String
    let uninstallerCommandBarBrowseTitle: String
    let uninstallerCommandBarFinderTitle: String
    let uninstallerSelectionUnavailable: String

    // MARK: Feature — URL cleaner
    let urlCleanerName: String
    let urlCleanerActiveNow: String
    let urlCleanerManualTitle: String
    let urlCleanerInputPlaceholder: String
    let urlCleanerOutputPlaceholder: String
    let urlCleanerPasteButton: String
    let urlCleanerCopyButton: String
    let urlCleanerClearButton: String
    let urlCleanerNoURL: String
    let urlCleanerNoChange: String
    let urlCleanerCleaned: String
    let urlCleanerCopied: String

    // MARK: Feature — Homebrew manager
    let homebrewName: String
    let homebrewMissingTitle: String
    let homebrewMissingBody: String
    let homebrewInstallHomebrew: String
    let homebrewInstallHomebrewCaption: String
    let homebrewInstallHomebrewOpened: String
    let homebrewShellSetupTitle: String
    let homebrewShellSetupBody: String
    let homebrewShellSetupButton: String
    let homebrewShellSetupOpened: String
    let homebrewRefresh: String
    let homebrewTrustTitle: String
    let homebrewTrustCaption: String
    let homebrewTrustButton: String
    let homebrewInstalled: String
    let homebrewAll: String
    let homebrewNoPackages: String
    let homebrewGroupDependencies: String
    let homebrewInstall: String
    let homebrewUninstall: String
    let homebrewUpgrade: String
    let homebrewUpgradeAll: String
    let homebrewUpdateHomebrew: String
    let homebrewAllPackages: String
    let homebrewOpenTerminal: String
    let homebrewCancelOperation: String
    let homebrewClearLog: String
    let homebrewHomepage: String
    let homebrewPopularityFormat: String
    let homebrewInstalledBadge: String
    let homebrewConfirmInstallBodyFormat: String
    let homebrewConfirmUninstallTitle: String
    let homebrewConfirmUninstallBodyFormat: String
    let homebrewConfirmUpgradeBodyFormat: String
    let homebrewConfirmUpgradeAllTitle: String
    let homebrewConfirmUpgradeAllBody: String
    let homebrewConfirmUpdateHomebrewTitle: String
    let homebrewConfirmUpdateHomebrewBody: String
    let homebrewTerminalFallback: String
    let homebrewLoading: String
    let homebrewOperationInstallFormat: String
    let homebrewOperationUninstallFormat: String
    let homebrewOperationUpgradeFormat: String
    let homebrewOperationUpgradeAll: String
    let homebrewOperationUpdateHomebrew: String
    let homebrewOperationInstalledFormat: String
    let homebrewOperationUninstalledFormat: String
    let homebrewOperationUpgradedFormat: String
    let homebrewOperationUpgradedAll: String
    let homebrewOperationUpdatedHomebrew: String
    let homebrewOperationFailedFormat: String
    let homebrewOperationCancelled: String
    let homebrewOperationPreparing: String
    let homebrewOperationDownloading: String
    let homebrewOperationInstalling: String
    let homebrewOperationUninstalling: String
    let homebrewOperationUpgrading: String
    let homebrewOperationFinalizing: String
    let homebrewOperationRefreshing: String
    let homebrewOperationTerminal: String
    let homebrewOperationElapsedFormat: String
    let homebrewOperationShowDetails: String
    let homebrewOperationHideDetails: String
    let homebrewOperationTechnicalLog: String
    let homebrewOperationProgressUnknown: String

    // MARK: Feature — local media tools
    let mediaName: String
    let mediaLocalNote: String
    let mediaToolVideo: String
    let mediaToolGIF: String
    let mediaToolImage: String
    let mediaToolText: String
    let mediaSelectFile: String
    let mediaDropHint: String
    let mediaOutput: String
    let mediaOutputAutomatic: String
    let mediaChooseOutput: String
    let mediaStartVideo: String
    let mediaStartGIF: String
    let mediaStartImage: String
    let mediaStartConvertPDF: String
    let mediaStartText: String
    let mediaCancel: String
    let mediaStartTime: String
    let mediaEndTime: String
    let mediaQuality: String
    let mediaCompressionLow: String
    let mediaCompressionMedium: String
    let mediaCompressionHigh: String
    let mediaCompressionLowDescription: String
    let mediaCompressionMediumDescription: String
    let mediaCompressionHighDescription: String
    let mediaMaxSize: String
    let mediaSizingResolution: String
    let mediaSizingFileSize: String
    let mediaTargetSize: String
    let mediaTargetSizeHint: String
    let mediaErrorTargetTooSmall: String
    let mediaMegabytesSuffix: String
    let mediaWidth: String
    let mediaFPS: String
    let mediaFormat: String
    let mediaStripMetadata: String
    let mediaLoopGIF: String
    let mediaOCRMode: String
    let mediaOCRAccurate: String
    let mediaOCRFast: String
    let mediaRunning: String
    let mediaCompleted: String
    let mediaCancelled: String
    let mediaOpenInFinder: String
    let mediaCopyText: String
    let mediaRunAgain: String
    let mediaEmptyText: String
    let mediaResultSavedFormat: String
    let mediaResultSizeFormat: String
    let mediaResultGrewCaption: String
    let mediaErrorNoFile: String
    let mediaErrorNoVideo: String
    let mediaErrorSameOutput: String
    let mediaErrorUnsupported: String

    // MARK: Feature — temporary shelf
    let shelfName: String
    let shelfEnable: String
    let shelfShakeToggle: String
    let shelfShakeCaption: String
    let shelfDropZoneToggle: String
    let shelfDropZoneCaption: String
    let shelfDropZoneCaptionTopCenter: String
    let shelfDockPlacement: String
    let shelfDockMenuBar: String
    let shelfDockTopCenter: String
    let shelfDockIslandNote: String
    let shelfCollapse: String
    let shelfBehaviorTitle: String
    let shelfCloseAfterDrop: String
    let shelfCloseAfterDropCaption: String
    let shelfRemoveAfterDrop: String
    let shelfRemoveAfterDropCaption: String
    let shelfExclusionsTitle: String
    let shelfExclusionsEmpty: String
    let shelfExclusionsCaption: String
    let shelfPin: String
    let shelfUnpin: String
    let extraBrightnessName: String
    let extraBrightnessCaption: String
    let extraBrightnessLevelLabel: String
    let extraBrightnessUnsupported: String
    let shelfOpenNow: String
    let shelfTitle: String
    let shelfEmpty: String
    let shelfClearAll: String
    let shelfRemoveSelected: String
    let shelfSelectedFormat: String      // + count
    let shelfHint: String
    let shelfItemImage: String
    // Three forms, not two: Russian and Ukrainian agree a noun with the number
    // in front of it as one, as two through four, and as five or more. Every other
    // language here needs only the first and the last, and repeats the last
    // in the middle slot. A pile always holds two or more, so the items count
    // has no singular of its own.
    let shelfTooltipItemsFormat: String      // + count, five or more
    let shelfTooltipItemsFew: String         // + count, two through four
    let shelfTooltipImageSingular: String    // + count == 1
    let shelfTooltipImageFew: String         // + count, two through four
    let shelfTooltipImagePlural: String      // + count
    let shelfTooltipFileSingular: String     // + count == 1
    let shelfTooltipFileFew: String          // + count, two through four
    let shelfTooltipFilePlural: String       // + count
    let shelfTooltipNoteSingular: String     // + count == 1
    let shelfTooltipNoteFew: String          // + count, two through four
    let shelfTooltipNotePlural: String       // + count
    let shelfTooltipLinkSingular: String     // + count == 1
    let shelfTooltipLinkFew: String          // + count, two through four
    let shelfTooltipLinkPlural: String       // + count
    let shelfActionOpen: String
    let shelfActionOpenWith: String
    let shelfActionShare: String
    let shelfActionPin: String
    let shelfActionUnpin: String

    // MARK: Panel — per-app breakdown
    let breakdownMeasuring: String

    // MARK: Panel — volume mixer
    let mixerSection: String
    let mixerEmpty: String
    let mixerUnavailable: String
    let mixerPermissionBody: String
    let mixerOutputDefault: String
    let mixerOutputUnavailable: String
    let mixerBypassedCaption: String
    let mixerSystemOutputTitle: String
    let mixerSystemOutputNoDevices: String
    let mixerLowerOnHeadphonesDisconnect: String
    let mixerLowerOnHeadphonesDisconnectCaption: String
    let mixerHeadphonesDisconnectVolume: String
    let volumeMixerEnable: String
    let preciseVolumeRollerTapFailed: String
    let soundOutputSwitcherTitle: String
    let soundOutputSwitcherEnable: String
    let soundOutputSwitcherCaption: String
    let mixerInputTitle: String
    let mixerInputNoDevices: String
    let mixerInputUnavailable: String
    let mixerInputTooltip: String
    let mixerInputErrorFormat: String
    let microphoneControlEnable: String
    let mixerInputLevelLabel: String
    let mixerInputSourceLabel: String
    let muteAudioInputSubtitle: String
    let manageAudioInputPriorityTitle: String
    let manageAudioOutputPriorityTitle: String
    let mixerOutputLevelLabel: String
    let screenshotEnable: String
    let screenRecorderEnable: String

    // MARK: Panel — audio device priority
    let audioPriorityOutputEnable: String
    let audioPriorityInputEnable: String
    let audioPriorityOutputList: String
    let audioPriorityInputList: String
    let audioPriorityMoveUp: String
    let audioPriorityMoveDown: String
    let audioPriorityUnavailable: String
    let audioPriorityCurrent: String
    let mixerOutputDeviceLabel: String
    let mixerSystemSoundLabel: String
    let mixerVolumeKeyStep: String
    let mixerVolumeKeyStepCaption: String
    let mixerVolumeKeyStepStandard: String
    let mixerVolumeKeyStepSmaller: String
    let mixerAppVolumesTitle: String
    let mixerShowInactiveAppsFormat: String
    let mixerHideInactiveApps: String
    let mixerOutputFollowSystem: String
    let mixerAppVolumeFormat: String
    let audioPrioritySkipCycling: String
    let audioPrioritySetOutput: String
    let audioPrioritySetInput: String

    // MARK: Settings — updates
    let updatesSection: String
    let betaBadgeLabel: String
    let updateChecking: String
    let updateUpToDate: String
    let updateAvailablePrefix: String  // + version
    let updateInstallButton: String
    let updateDownloading: String
    let updateInstalling: String
    let updateFailedPrefix: String
    let updateLastChecked: String
    let updateNotifyTitle: String
    let updateInstallFailedBody: String
    let updateNeedsApplicationsTitle: String
    let updateNeedsApplicationsBody: String

    // MARK: Permissions
    let permissionRequired: String
    let permissionAccessibility: String
    let permissionScreenRecording: String
    let permissionGranted: String
    let permissionMissing: String
    let permissionOpenSettings: String
    let permissionRequest: String
    let permissionRestartNote: String

    // MARK: Secure input
    let secureInputTitle: String
    let secureInputHeldFormat: String
    let secureInputUnattributed: String
    let secureInputUnidentified: String
    let secureInputRevealFormat: String

    // MARK: About
    let aboutDescription: String
    let versionPrefix: String

    // MARK: Onboarding
    let navigationBack: String
    let releaseNotesFallback: String

    // MARK: Settings — monitor / menu bar metrics
    let tabMonitor: String
    let monitorSeparateMenuBarMetrics: String
    let monitorSeparateMenuBarMetricsCaption: String
    let monitorNetworkUploadFirst: String
    let monitorShowCPU: String
    let monitorShowMemory: String
    let monitorShowNetwork: String
    let monitorShowPowerLabel: String
    let betaBadge: String
    let betaFeatureWarning: String

    // MARK: Panel — network
    let networkSection: String
    let networkApps: String
    let networkAppsIdle: String

    // MARK: Panel — disk
    let diskSection: String
    let diskMenuBarStyleLabel: String
    let diskMenuBarUsedPercentage: String
    let diskMenuBarAvailableSpace: String
    let diskMenuBarUsedSpace: String
    let diskAvailable: String
    let diskPurgeable: String
    let diskStorageSettings: String
    let diskNoDisks: String

    // MARK: Panel — power
    let powerSection: String
    let powerCharging: String
    let powerOnBattery: String
    let powerPluggedIn: String
    let powerUnavailable: String
    let powerAdapterMaxFormat: String   // + rated watts, e.g. "30 W max"
    let monitorShowGPU: String
    let monitorShowCPUTemperature: String
    let monitorShowGPUTemperature: String
    let monitorShowBatteryTemperature: String
    let monitorShowPeripheralBattery: String

    // MARK: Update notification + menu bar setup
    let updateBannerTitle: String
    let menuBarSpacingLabel: String
    let menuBarSpacingStandard: String
    let menuBarSpacingCompact: String
    let monitorMemoryPressureDot: String
    // MARK: System uptime, battery health, speed test
    let systemUptime: String
    let powerCycles: String
    let speedTestRun: String

    // MARK: Per-item panel config
    let disclosureExpanded: String
    let disclosureCollapsed: String
    let panelHiddenItem: String
    let monitorItemDiskUsage: String
    let monitorItemDiskActivity: String

    // MARK: Cleaning mode
    let cleaningMenuItem: String
    let windowMaximizeName: String
    let windowMaximizeCaption: String
    let keyDebounceName: String
    let keyDebounceEnable: String
    let keyDebounceCaption: String
    let keyDebounceGlobalWindow: String
    let keyDebouncePerKeySection: String
    let keyDebouncePerKeyCaption: String
    let keyDebounceKeyLabel: String
    let keyDebounceAddKey: String
    let keyDebounceRemoveKey: String
    let cleaningPanelCaption: String
    let cleaningOverlayTitle: String
    let cleaningOverlaySubtitle: String
    let cleaningOverlayUnlock: String
    let cleaningOverlayMouseHint: String
    let cleaningNeedsAxTitle: String
    let cleaningNeedsAxBody: String

    // MARK: Support / donate
    let shortcutsPageTitle: String
    let settingsSearchPlaceholder: String
    /// A quiet line under the donation button inviting a GitHub star instead.
    let doneButton: String
    let homebrewOfficialIntroTitle: String
    let homebrewOfficialIntroMessage: String
    let homebrewOfficialIntroInstallLabel: String
    let homebrewOfficialIntroMigrationTitle: String
    let homebrewOfficialIntroMigrationMessage: String
    let homebrewOfficialIntroCopyButton: String

    // MARK: Configurable shortcuts
    let shortcutRecording: String
    let shortcutReset: String
    let shortcutNone: String
    let shortcutClear: String
    let shortcutInvalid: String
    let shortcutPressKeys: String
    let shortcutEscapeHint: String
    let shortcutDeleteHint: String
    let shortcutConflictFormat: String
    let shortcutTakeOverOffer: String
    let shortcutTakeOverAction: String
    let shortcutTakeOverCaption: String
    let shortcutTakeOverDismiss: String
    let shortcutUnavailable: String

    // MARK: Media keys
    let musicBlockSection: String
    let musicBlockTitle: String
    let musicBlockCaption: String
    let musicBlockUnavailable: String
    let musicBlockPlayReplacement: String

    // MARK: Cleaner
    let cleanerName: String
    let cleanerIntroTitle: String
    let cleanerIntroCaption: String
    let cleanerScan: String
    let cleanerScanning: String
    let cleanerCleaning: String
    let cleanerCatLeftovers: String
    let cleanerCatLoginItems: String
    let cleanerCatCaches: String
    let cleanerCatLogs: String
    let cleanerCatDeveloper: String
    let cleanerCatTrash: String
    let cleanerLeftoversNote: String
    let cleanerLoginItemsNote: String
    let cleanerTrashNote: String
    let cleanerCatDeviceBackups: String
    let cleanerDeviceBackupsCaption: String
    let cleanerCatScreenshots: String
    let cleanerScreenshotsCaptionFormat: String
    let cleanerScreenshotsSettingCaption: String
    let cleanerScreenshotsAfterFormat: String
    let cleanerNothingFound: String
    let cleanerDoneNote: String
    let cleanerAgain: String
    let cleanerRevealInFinder: String
    let cleanerSafeSection: String
    let cleanerOptionalSection: String
    let cleanerCatOtherCaches: String
    let cleanerCachesCaption: String
    let cleanerLogsCaption: String
    let cleanerDeveloperCaption: String
    let cleanerLoginItemsCaption: String
    let cleanerLeftoversCaption: String
    let cleanerOtherCachesCaption: String
    let cleanerCleanSizeFormat: String      // + size string
    let cleanerScheduleTitle: String
    let cleanerScheduleOff: String
    let cleanerScheduleDaily: String
    let cleanerScheduleWeekly: String
    let cleanerScheduleCaption: String
    let cleanerScheduleLastFormat: String   // + size string
    let cleanerAutoNotificationFormat: String  // + size string
    let cleanerScheduleNextFormat: String   // + relative date and time
    let cleanerScheduleRanFormat: String    // + relative date and time
    let cleanerScheduleNotifyToggle: String
    let cleanerNotifDenied: String
    let cleanerNotifOpenSettings: String
    let launchAtLoginNeedsApplications: String
    let launchAtLoginNeedsApproval: String
    let ocrRemoveLineBreaksToggle: String
    let ocrRemoveLineBreaksCaption: String
    let ocrQRToggle: String
    let ocrQRCaption: String
    let ocrQRCopied: String
    let qrResultTitle: String
    let qrResultCopy: String
    let qrResultOpen: String
    let switcherCurrentSpaceOnly: String
    let switcherCurrentSpaceOnlyCaption: String
    let shelfFileMissing: String
    let previewSizeSmall: String
    let mixerSoundEffectsOutputTitle: String
    let mixerSoundEffectsOutputTooltip: String
    let monitorOpenActivityMonitor: String
    let dockClickHide: String
    let dockClickHideCaption: String
    let urlCleanerRemovedFormat: String            // + comma separated names
    let switcherSearchPlaceholder: String
    let invertVerticalScroll: String
    let invertHorizontalScroll: String
    let scrollHorizontalName: String
    let scrollHorizontalModifierLabel: String
    let scrollHorizontalCommandKey: String
    let scrollHorizontalCaption: String
    let switcherShowShortcutHints: String
    let switcherShowShortcutHintsCaption: String
    let uninstallerHomebrewPackageFormat: String
    let uninstallerHomebrewCheckFailed: String
    let shelfEdgeToggle: String
    let shelfEdgeCaption: String
    let focusFollowsMouseName: String
    let focusFollowsMouseCaption: String
    let focusFollowsMouseDelay: String
    let focusFollowsMouseRaise: String
    let focusFollowsMouseWaitForStop: String
    let switcherMinimizedPlacementLabel: String
    let switcherMinimizedPlacementNormal: String
    let switcherMinimizedPlacementEnd: String
    let switcherMinimizedPlacementHidden: String
    let switcherShowFullscreenWindows: String
    let switcherScreenPlacementLabel: String
    let switcherScreenPlacementPointer: String
    let switcherScreenPlacementMenuBar: String
    let switcherScreenPlacementActiveWindow: String
    let switcherCurrentDisplayOnly: String
    let switcherCurrentDisplayOnlyCaption: String
    let smoothScrollResponseLabel: String
    let smoothScrollCoastLabel: String
    let mouseAccelerationName: String
    let mouseAccelerationCaption: String
    let linearScrollName: String
    let linearScrollCaption: String
    let linearScrollLinesLabel: String
    let scrollSpeedName: String
    let scrollSpeedCaption: String
    let scrollSpeedMultiplierLabel: String
    let shelfClearOnClose: String
    let shelfClearOnCloseCaption: String
    let shelfShortcutFinderSelection: String
    let shelfShortcutFinderSelectionCaption: String
    let spacesOrderName: String
    let spacesOrderCaption: String
}

// MARK: - Português (Brasil)

extension Strings {
    static let ptBR = Strings(
        menuEnableAwake: "Ativar manter acordado",
        menuDisableAwake: "Desativar manter acordado",
        menuSettings: "Ajustes…",
        menuAbout: "Sobre o Lattice",
        menuQuit: "Sair do Lattice",
        menuHide: "Ocultar o Lattice",
        menuHideOthers: "Ocultar Outros",
        menuShowAll: "Mostrar Tudo",
        menuEdit: "Editar",
        menuUndo: "Desfazer",
        menuRedo: "Refazer",
        actionClear: "Limpar",
        actionMute: "Silenciar",
        actionUnmute: "Reativar som",
        actionPause: "Pausar",
        menuCut: "Recortar",
        menuCopy: "Copiar",
        menuPaste: "Colar",
        menuSelectAll: "Selecionar Tudo",
        menuWindow: "Janela",
        menuMinimize: "Minimizar",
        menuZoom: "Zoom",
        menuClose: "Fechar",

        minutes15: "15 minutos",
        minutes30: "30 minutos",
        hour1: "1 hora",
        hours2: "2 horas",
        hours4: "4 horas",
        hours8: "8 horas",
        indefinitely: "Indefinidamente",
        indefinite: "Indefinida",

        panelQuit: "Sair",

        keepAwakeTitle: "Ficar acordado",
        keepAwakeEndsIn: "Termina em",
        keepAwakeUntilDisabled: "Ativo até você desativar",

        temperatures: "Temperaturas",
        cpuLabel: "CPU",
        gpuLabel: "GPU",
        batteryLabel: "Bateria",
        memorySection: "Memória",
        memoryPressure: "Pressão",
        memorySwapUsed: "Swap em uso",
        memoryCompressed: "Comprimida",
        memoryCachedFiles: "Arquivos em cache",
        pressureNormal: "Normal",
        pressureWarning: "Atenção",
        pressureCritical: "Crítico",
        monitorUnavailable: "Sensores indisponíveis neste Mac",
        energyAppsIdle: "Sem uso significativo de energia",

        notifySessionEndedTitle: "Sessão encerrada",
        notifySessionEndedBody: "O tempo acabou. O Mac voltará a suspender normalmente.",
        notifyBatteryTitle: "Lattice desativado",
        notifyBatteryBody: "Bateria baixa. A suspensão normal foi restaurada para proteger a carga.",
        adminPromptClamshellOff: "O Lattice precisa da sua senha para reativar a suspensão normal do Mac.",
        adminPromptRecover: "O Lattice foi encerrado com a suspensão do Mac desativada. Digite a senha para restaurar a suspensão normal.",
        adminPromptUpdate: "O Lattice precisa da sua senha para instalar a atualização.",
        adminPromptSudoersInstall: "O Lattice vai criar uma regra restrita (somente pmset disablesleep) para alternar a tampa fechada sem pedir senha. Esta é a única vez que a senha será necessária.",
        adminPromptSudoersRemove: "O Lattice vai remover a regra de tampa fechada sem senha.",

        settingsTitle: "Ajustes do Lattice",
        tabGeneral: "Geral",
        tabEnergy: "Energia",
        tabMouse: "Mouse e Trackpad",
        tabSwitcher: "Alternador de apps",
        tabAbout: "Sobre",
        tabReleaseNotes: "Novidades",
        minimalWindowPreviews: "Ocultar título e controles da prévia",
        minimalWindowPreviewsCaption: "Mostra apenas a prévia da janela e oculta título e controles.",
        previewSizeLabel: "Tamanho dos previews",
        previewSizeNormal: "Normal",
        previewSizeLarge: "Grande",
        previewSizeXLarge: "Extra grande",
        advancedClearButton: "Limpar todas as permissões",
        advancedClearFailed: "Redefinição incompleta. Os controles de entrada continuam pausados. Reinicie o Lattice e confira as permissões e os Itens de Início nos Ajustes do Sistema.",
        advancedUninstallDescription: "Remova o Lattice e suas configurações do seu Mac.",
        advancedUninstallButton: "Desinstalar o Lattice",
        advancedUninstallConfirmTitle: "Desinstalar o Lattice?",
        advancedUninstallConfirmBody: "O app Lattice será movido para a Lixeira. Suas configurações e os dados do app serão excluídos permanentemente e não poderão ser recuperados da Lixeira.",
        advancedUninstallFailedTitle: "A desinstalação parou",
        advancedUninstallFailedBody: "O Lattice não conseguiu restaurar uma configuração do sistema que ele mudou: repouso, velocidade das ventoinhas, aceleração do mouse ou ordem dos Espaços. Nada foi removido. Tente de novo e permita o pedido de senha, se ele aparecer.",

        launchAtLogin: "Iniciar junto com o Mac",
        languageLabel: "Idioma",
        hotkeyToggle: "Ativar atalho para “Manter acordado”",

        batteryNever: "Nunca",
        configuring: "Configurando…",
        sudoersFailed: "Não foi possível ativar a tampa fechada. Tente de novo.",

        invertMouseScroll: "Inverter rolagem do mouse",
        scrollTrackpadNote: "O trackpad não muda: continua com a rolagem natural do macOS.",
        smoothScrollName: "Rolagem suave",
        smoothScrollCaption: "Transforma cada passo da rodinha do mouse em um deslize curto e macio. O trackpad não muda.",
        smoothScrollStepLabel: "Velocidade da rolagem",
        mouseNavigationEnable: "Navegação com botões laterais",
        middleClickSection: "Botão do meio no trackpad",
        middleClickEnable: "Gesto de clique do meio",
        middleClickEnableCaption: "Use o trackpad para as ações do clique do meio do mouse.",
        middleClickNoTrackpad: "Não é possível ler os toques no trackpad. Conecte um trackpad compatível.",
        middleClickTapPicker: "Tocar com",
        middleClickTapOff: "Desligado",
        middleClickTapThreeFingers: "3 dedos",
        middleClickTapFourFingers: "4 dedos",
        middleClickTapCaption: "Um toque leve com esse número de dedos, sem pressionar, também dispara o clique do meio. Deslizar nunca conta. Se o toque de três dedos do macOS estiver atribuído à Busca, desative-o para os dois não abrirem juntos.",
        ocrName: "Copiar texto da tela",
        ocrCaption: "Selecione uma área da tela e o texto reconhecido é copiado, pronto para colar.",
        ocrCopied: "Texto copiado",
        ocrNoText: "Nenhum texto encontrado",
        colorPickerName: "Conta-gotas de cor",
        colorPickerCaption: "Capture a cor de qualquer pixel da tela e copie no formato que preferir.",
        micMuteName: "Silenciar microfone",
        micUnmuteName: "Reativar microfone",
        micMuteCaption: "Corta o microfone do Mac com um clique ou atalho, valendo para qualquer app.",
        micMuteFollowCallAppsToggle: "Permitir que apps de chamada reativem o microfone",
        micMuteFollowCallAppsCaption: "Quando um app está gravando e o microfone em uso é reativado, o Lattice restaura todos os microfones que silenciou. Um ajuste automático de ganho também pode causar isso.",
        micMutedHUD: "Microfone silenciado",
        micUnmutedHUD: "Silenciamento desativado",
        micMutePartialHUD: "Alguns microfones não puderam ser silenciados",
        micUnmutePartialHUD: "Alguns microfones continuam silenciados",
        micMuteMenuBarToggle: "Mostrar estado de silêncio na barra de menus",
        pastePlainName: "Colar como texto puro",
        pastePlainCaption: "Cola o que foi copiado sem cores, fontes ou formatação. O conteúdo original continua no clipboard.",
        launcherName: "Lattice Hub",

        switcherSection: "Alternador de apps",
        switcherNoWindows: "Nenhuma janela aberta",
        switcherIconRowMode: "Mostrar %@ com ícones grandes",
        switcherIconRowModeCaption: "Mostra um ícone por app com os previews das janelas do app acima.",
        switcherSimpleModeCaption: "Mostra ícones de apps e títulos das janelas, sem previews nem captura da tela pelo alternador.",
        switcherShortcutHintApps: "Apps",
        switcherShortcutHintWindows: "Janelas",
        switcherAppearanceDelay: "Atraso ao segurar",
        switcherAppearanceDelayCaption: "Quanto tempo o atalho precisa ficar pressionado antes de o alternador aparecer.",
        switcherMaxColumns: "Máximo de colunas",
        switcherMaxColumnsCaption: "Quebra para mais linhas depois desse número de itens. Útil em monitores ultrawide.",
        switcherMaxColumnsAuto: "Automático",
        switcherInstantSelection: "Seleção instantânea",
        switcherIgnoreHoverSelection: "Ignorar seleção ao passar o cursor",
        switcherMergeTabs: "Agrupar janelas por app",
        switcherMergeTabsCaption: "Uma entrada por app em vez de uma por janela.",
        switcherWindowlessApps: "Ocultar apps sem janelas",
        switcherWindowlessAppsFinder: "Não ocultar o Finder",
        switcherNoOpenWindow: "Sem janela aberta",
        switcherOtherDesktop: "Outra Mesa",
        dockPreviewName: "Dock Preview",
        dockPreviewEnable: "Pré-visualizar janelas no Dock",
        dockPreviewCurrentSpaceOnly: "Mostrar apenas janelas da mesa atual",
        dockPreviewCurrentSpaceOnlyCaption: "Ocultar janelas de outras mesas.",
        dockPreviewCurrentSpaceOnlyInfo: "Selecionar uma janela em outra mesa alterna automaticamente para ela.",
        dockPreviewBackgroundOpacity: "Fundo do painel",
        dockPreviewBackgroundOpacityCaption: "Diminua para ver mais do que está atrás do painel.",
        dockPreviewBackgroundOpacityGlassCaption: "Com o Liquid Glass ligado, a transparência do painel é definida em Ajustes do Sistema > Aparência.",
        dockPreviewOpenDelay: "Atraso ao passar o mouse",
        dockPreviewOpenDelayCaption: "Atraso antes de exibir prévias ao apontar para um ícone.",
        dockPreviewDelayDefault: "Padrão",
        dockPreviewDelayLonger: "Mais longo",
        dockPreviewQuitApplication: "Encerrar aplicativo",
        dockPreviewKeepDockVisible: "Manter Dock visível durante o preview",
        dockPreviewKeepDockVisibleCaption: "Impede que o Dock se oculte enquanto o preview está aberto.",
        dockPreviewOrderByCreation: "Mostrar janelas mais antigas primeiro",
        dockPreviewOrderByCreationCaption: "Listar janelas na ordem em que foram abertas, em vez de por atividade recente.",
        dockClickMinimize: "Clicar no Dock minimiza",
        dockClickCycleWindows: "Clicar no Dock alterna janelas",
        dockPreviewDockUnavailable: "Não foi possível ler os itens do Dock.",
        dockPreviewOpenWindow: "Abrir janela",
        dockPreviewCloseWindow: "Fechar janela",
        dockPreviewMinimizeWindow: "Minimizar janela",
        dockPreviewRestoreWindow: "Restaurar janela",
        dockPreviewPinPanel: "Fixar prévia",
        dockPreviewUnpinPanel: "Desfixar prévia",
        dockPreviewPinned: "Fixado",
        dockPreviewClosePanel: "Fechar prévia",
        dockPreviewPreviousWindow: "Janela anterior",
        dockPreviewNextWindow: "Próxima janela",

        finderAutomationNote: "Na primeira vez, o macOS pede permissão para controlar o Finder.",

        autoQuitName: "Encerrar o app quando nenhuma janela estiver aberta",
        autoQuitEnable: "Encerrar o app ao fechar a última janela",
        autoQuitEnableCaption: "Fechar a última janela de um app também o encerra.",
        autoQuitExceptionsTitle: "Exceções",

        uninstallerName: "Desinstalador",
        uninstallerChoose: "Escolher app…",
        uninstallerPickerTitle: "Escolher app",
        uninstallerPickerSearch: "Buscar apps",
        uninstallerPickerEmpty: "Nenhum app encontrado",
        uninstallerFDANote: "Conceda Acesso Total ao Disco para uma análise mais completa.",
        uninstallerFDAGrant: "Conceder acesso…",
        uninstallerFDAHint: "Ative o Lattice na lista. Se ele não aparecer, clique no + e escolha o Lattice em Aplicativos. O acesso só vale depois de reabrir o app.",
        uninstallerFDARelaunch: "Reabrir agora",
        uninstallerScanning: "Analisando arquivos…",
        uninstallerRemoving: "Movendo para a Lixeira…",
        uninstallerFoundTitle: "encontrado",
        uninstallerSelectedFormat: "%d de %d selecionados",
        uninstallerSelectAll: "Selecionar tudo",
        uninstallerRemove: "Mover para a Lixeira",
        uninstallerCancel: "Cancelar",
        uninstallerConfirmationExpired: "Esta confirmação não é mais válida. Revise os itens atuais e confirme de novo.",
        uninstallerDoneTitle: "Pronto!",
        uninstallerFreedFormat: "%@ removidos",
        uninstallerSomeFailed: "Alguns itens não puderam ser movidos para a Lixeira.",
        uninstallerFailedNeedsFDA: "Os dados de apps em área restrita só podem ser movidos com Acesso Total ao Disco. A senha de administrador não substitui essa permissão.",
        uninstallerFailedMoreFormat: "e mais %d",
        uninstallerAnother: "Desinstalar outro",
        uninstallerCatApp: "Aplicativo",
        uninstallerCatSupport: "Suporte",
        uninstallerCatCaches: "Caches",
        uninstallerCatPreferences: "Preferências",
        uninstallerCatContainers: "Contêineres",
        uninstallerCatLogs: "Logs",
        uninstallerCatState: "Estado salvo",
        uninstallerCatOther: "Outros",
        uninstallerCommandBarBrowseTitle: "Desinstalar aplicativo",
        uninstallerCommandBarFinderTitle: "Desinstalar aplicativo selecionado no Finder",
        uninstallerSelectionUnavailable: "Selecione um aplicativo que possa ser removido no Finder ou escolha outro na lista.",

        urlCleanerName: "Limpador de URL",
        urlCleanerActiveNow: "Ativo agora",
        urlCleanerManualTitle: "Limpar agora",
        urlCleanerInputPlaceholder: "Cole uma URL",
        urlCleanerOutputPlaceholder: "A URL limpa aparece aqui",
        urlCleanerPasteButton: "Colar",
        urlCleanerCopyButton: "Copiar",
        urlCleanerClearButton: "Limpar campo",
        urlCleanerNoURL: "Cole uma URL válida.",
        urlCleanerNoChange: "Nada para limpar.",
        urlCleanerCleaned: "URL limpa.",
        urlCleanerCopied: "Copiado.",

        homebrewName: "Homebrew",
        homebrewMissingTitle: "Homebrew não encontrado",
        homebrewMissingBody: "O Lattice pode abrir o instalador oficial do Homebrew no seu terminal. Ele mostra os passos e pede sua senha se precisar.",
        homebrewInstallHomebrew: "Instalar Homebrew",
        homebrewInstallHomebrewCaption: "Depois que o instalador terminar, volte aqui e clique em Atualizar.",
        homebrewInstallHomebrewOpened: "Instalador aberto no seu terminal.",
        homebrewShellSetupTitle: "Finalizar configuração do terminal",
        homebrewShellSetupBody: "O Homebrew está instalado, mas o seu terminal ainda pode não encontrar o comando brew. O Lattice pode abrir o comando de configuração no seu terminal.",
        homebrewShellSetupButton: "Configurar terminal",
        homebrewShellSetupOpened: "Comando aberto no seu terminal. Depois volte aqui e clique em Atualizar.",
        homebrewRefresh: "Atualizar",
        homebrewTrustTitle: "Tap ainda não confiável",
        homebrewTrustCaption: "O Homebrew agora pede sua confirmação antes de usar taps de terceiros. Confie em %@ para continuar.",
        homebrewTrustButton: "Confiar e continuar",
        homebrewInstalled: "Instalados",
        homebrewAll: "Todos",
        homebrewNoPackages: "Nenhum pacote encontrado",
        homebrewGroupDependencies: "Agrupar dependências",
        homebrewInstall: "Instalar",
        homebrewUninstall: "Desinstalar",
        homebrewUpgrade: "Atualizar",
        homebrewUpgradeAll: "Atualizar tudo",
        homebrewUpdateHomebrew: "Atualizar Homebrew",
        homebrewAllPackages: "pacotes",
        homebrewOpenTerminal: "Abrir terminal",
        homebrewCancelOperation: "Cancelar",
        homebrewClearLog: "Limpar log",
        homebrewHomepage: "Abrir site",
        homebrewPopularityFormat: "%@ instalações em %@ dias",
        homebrewInstalledBadge: "Instalado",
        homebrewConfirmInstallBodyFormat: "O Homebrew vai baixar e instalar %@. Dependências também podem ser instaladas.",
        homebrewConfirmUninstallTitle: "Desinstalar pelo Homebrew?",
        homebrewConfirmUninstallBodyFormat: "O Homebrew vai desinstalar %@. Arquivos de configuração podem permanecer no sistema.",
        homebrewConfirmUpgradeBodyFormat: "O Homebrew vai baixar e aplicar a versão mais recente de %@. Dependências também podem ser atualizadas.",
        homebrewConfirmUpgradeAllTitle: "Atualizar todos pelo Homebrew?",
        homebrewConfirmUpgradeAllBody: "O Homebrew vai baixar e aplicar as versões mais recentes dos pacotes com atualização disponível. Dependências também podem ser atualizadas.",
        homebrewConfirmUpdateHomebrewTitle: "Atualizar Homebrew?",
        homebrewConfirmUpdateHomebrewBody: "O Homebrew vai buscar as informações mais recentes e depois recarregar seus pacotes.",
        homebrewTerminalFallback: "Esta operação precisa do seu terminal para pedir a senha de administrador. O Lattice não captura senhas.",
        homebrewLoading: "Carregando…",
        homebrewOperationInstallFormat: "Instalando %@",
        homebrewOperationUninstallFormat: "Desinstalando %@",
        homebrewOperationUpgradeFormat: "Atualizando %@",
        homebrewOperationUpgradeAll: "Atualizando pacotes",
        homebrewOperationUpdateHomebrew: "Atualizando Homebrew",
        homebrewOperationInstalledFormat: "%@ instalado.",
        homebrewOperationUninstalledFormat: "%@ desinstalado.",
        homebrewOperationUpgradedFormat: "%@ atualizado.",
        homebrewOperationUpgradedAll: "Pacotes atualizados.",
        homebrewOperationUpdatedHomebrew: "Homebrew atualizado.",
        homebrewOperationFailedFormat: "Não foi possível concluir %@.",
        homebrewOperationCancelled: "Operação cancelada.",
        homebrewOperationPreparing: "Preparando…",
        homebrewOperationDownloading: "Baixando arquivos…",
        homebrewOperationInstalling: "Instalando arquivos…",
        homebrewOperationUninstalling: "Removendo arquivos…",
        homebrewOperationUpgrading: "Atualizando arquivos…",
        homebrewOperationFinalizing: "Finalizando…",
        homebrewOperationRefreshing: "Atualizando lista…",
        homebrewOperationTerminal: "Continue no seu terminal.",
        homebrewOperationElapsedFormat: "%@ decorridos",
        homebrewOperationShowDetails: "Mostrar detalhes",
        homebrewOperationHideDetails: "Ocultar detalhes",
        homebrewOperationTechnicalLog: "Detalhes técnicos",
        homebrewOperationProgressUnknown: "O Homebrew ainda não informou uma porcentagem.",

        mediaName: "Compressão de mídia",
        mediaLocalNote: "Local. Sem rede.",
        mediaToolVideo: "Vídeo",
        mediaToolGIF: "GIF",
        mediaToolImage: "Imagem",
        mediaToolText: "Texto",
        mediaSelectFile: "Escolher arquivo",
        mediaDropHint: "Arraste um arquivo aqui ou clique para escolher.",
        mediaOutput: "Saída",
        mediaOutputAutomatic: "Automática",
        mediaChooseOutput: "Destino",
        mediaStartVideo: "Comprimir vídeo",
        mediaStartGIF: "Criar GIF",
        mediaStartImage: "Processar imagem",
        mediaStartConvertPDF: "Converter em PDF",
        mediaStartText: "Extrair texto",
        mediaCancel: "Cancelar",
        mediaStartTime: "Início",
        mediaEndTime: "Fim",
        mediaQuality: "Compressão",
        mediaCompressionLow: "Baixa",
        mediaCompressionMedium: "Média",
        mediaCompressionHigh: "Alta",
        mediaCompressionLowDescription: "Alta qualidade, arquivo grande",
        mediaCompressionMediumDescription: "Equilíbrio entre qualidade e tamanho do arquivo",
        mediaCompressionHighDescription: "Baixa qualidade, arquivo pequeno",
        mediaMaxSize: "Tamanho",
        mediaSizingResolution: "Resolução",
        mediaSizingFileSize: "Tamanho do arquivo",
        mediaTargetSize: "Tamanho alvo",
        mediaTargetSizeHint: "A resolução se ajusta para ficar abaixo do limite.",
        mediaErrorTargetTooSmall: "Tamanho alvo pequeno demais para este clipe. Encurte-o ou aumente o limite.",
        mediaMegabytesSuffix: " MB",
        mediaWidth: "Largura",
        mediaFPS: "FPS",
        mediaFormat: "Formato",
        mediaStripMetadata: "Remover metadados",
        mediaLoopGIF: "Repetir GIF",
        mediaOCRMode: "OCR",
        mediaOCRAccurate: "Preciso",
        mediaOCRFast: "Rápido",
        mediaRunning: "Processando",
        mediaCompleted: "Concluído",
        mediaCancelled: "Cancelado.",
        mediaOpenInFinder: "Mostrar",
        mediaCopyText: "Copiar texto",
        mediaRunAgain: "Rodar de novo",
        mediaEmptyText: "Nenhum texto encontrado.",
        mediaResultSavedFormat: "Salvo como %@",
        mediaResultSizeFormat: "%@ para %@",
        mediaResultGrewCaption: "O arquivo convertido ficou maior que o original.",
        mediaErrorNoFile: "Escolha um arquivo primeiro.",
        mediaErrorNoVideo: "Este arquivo não tem trilha de vídeo.",
        mediaErrorSameOutput: "Escolha um destino diferente do arquivo original.",
        mediaErrorUnsupported: "Formato não suportado pelo macOS.",

        shelfName: SettingsOwnershipStrings.text(.fileCache, .ptBR),
        shelfEnable: "Área temporária para arrastar arquivos",
        shelfShakeToggle: "Abrir sacudindo o mouse durante o arraste",
        shelfShakeCaption: "Sacuda o ponteiro rapidamente segurando um item para chamar a área perto do cursor.",
        shelfDropZoneToggle: "Guardar arquivos na barra de menus ao arrastar",
        shelfDropZoneCaption: "Ao arrastar um arquivo, a área aparece embaixo do ícone na barra de menus. O que você soltar fica guardado ali, num botão que você encolhe e abre com um clique e que some quando a área fica vazia.",
        shelfDropZoneCaptionTopCenter: "Ao arrastar um arquivo, a área aparece como um selo no topo, no centro da tela. O que você soltar fica guardado ali, num selo que você abre com um clique e que some quando a área fica vazia.",
        shelfDockPlacement: "Posição",
        shelfDockMenuBar: "Embaixo do ícone da barra de menus",
        shelfDockTopCenter: "No topo, no centro da tela",
        shelfDockIslandNote: "Enquanto a Dynamic Island está ligada, o centro do topo é dela.",
        shelfCollapse: "Encolher",
        shelfBehaviorTitle: "Depois de usar",
        shelfCloseAfterDrop: "Fechar depois de soltar em outro app",
        shelfCloseAfterDropCaption: "Fecha a área quando o destino aceita os itens. O alfinete no painel a mantém aberta.",
        shelfRemoveAfterDrop: "Remover itens depois de soltar",
        shelfRemoveAfterDropCaption: "Itens aceitos por outro app saem da área. Desative para manter uma cópia nela. Itens fixados sempre ficam.",
        shelfExclusionsTitle: "Exceções automáticas",
        shelfExclusionsEmpty: "Nenhum app adicionado.",
        shelfExclusionsCaption: "Sacudir e a área da barra de menus não abrem durante arrastes iniciados nesses apps. O atalho e Abrir agora continuam funcionando.",
        shelfPin: "Manter aberta",
        shelfUnpin: "Deixar fechar após o uso",
        extraBrightnessName: "Brilho extra",
        extraBrightnessCaption: "Usa a reserva HDR da tela para passar do brilho máximo. Consome mais bateria e o Mac pode esquentar.",
        extraBrightnessLevelLabel: "Intensidade",
        extraBrightnessUnsupported: "Disponível apenas em telas XDR, como as dos MacBook Pro de 14 e 16 polegadas.",
        shelfOpenNow: "Abrir agora",
        shelfTitle: SettingsOwnershipStrings.text(.fileCache, .ptBR),
        shelfEmpty: "Arraste itens aqui",
        shelfClearAll: "Limpar tudo",
        shelfRemoveSelected: "Remover selecionados",
        shelfSelectedFormat: "%d selecionados",
        shelfHint: "Clique para selecionar. Arraste para usar ou clique com o botão direito para mais ações.",
        shelfItemImage: "Imagem",
        shelfTooltipItemsFormat: "%d itens",
        shelfTooltipItemsFew: "%d itens",
        shelfTooltipImageSingular: "%d imagem",
        shelfTooltipImageFew: "%d imagens",
        shelfTooltipImagePlural: "%d imagens",
        shelfTooltipFileSingular: "%d arquivo",
        shelfTooltipFileFew: "%d arquivos",
        shelfTooltipFilePlural: "%d arquivos",
        shelfTooltipNoteSingular: "%d nota",
        shelfTooltipNoteFew: "%d notas",
        shelfTooltipNotePlural: "%d notas",
        shelfTooltipLinkSingular: "%d link",
        shelfTooltipLinkFew: "%d links",
        shelfTooltipLinkPlural: "%d links",
        shelfActionOpen: "Abrir",
        shelfActionOpenWith: "Abrir com",
        shelfActionShare: "Compartilhar",
        shelfActionPin: "Fixar",
        shelfActionUnpin: "Desafixar",

        breakdownMeasuring: "Medindo…",

        mixerSection: "Mixer de volume",
        mixerEmpty: "Apps que usam áudio aparecem aqui",
        mixerUnavailable: "Disponível a partir do macOS 14.4",
        mixerPermissionBody: "Para ajustar o volume por app, permita “Gravação de Tela e Áudio do Sistema” nos Ajustes do Sistema. O áudio nunca é gravado.",
        mixerOutputDefault: "Padrão",
        mixerOutputUnavailable: "Saída indisponível",
        mixerBypassedCaption: "Este app controla o próprio áudio.",
        mixerSystemOutputTitle: "Saída",
        mixerSystemOutputNoDevices: "Nenhuma saída encontrada",
        mixerLowerOnHeadphonesDisconnect: "Baixar volume ao desconectar fones",
        mixerLowerOnHeadphonesDisconnectCaption: "Ajusta a saída quando fones com fio ou Bluetooth desconectam.",
        mixerHeadphonesDisconnectVolume: "Volume ao desconectar",
        volumeMixerEnable: "Controle de saída de áudio",
        preciseVolumeRollerTapFailed: "Não foi possível ouvir as teclas de volume.",
        soundOutputSwitcherTitle: "Alternador de saída",
        soundOutputSwitcherEnable: "Alternar com atalho",
        soundOutputSwitcherCaption: "Use o atalho para alternar entre os dispositivos de saída.",
        mixerInputTitle: "Microfone",
        mixerInputNoDevices: "Nenhum microfone encontrado",
        mixerInputUnavailable: "Microfone indisponível",
        mixerInputTooltip: "Escolher microfone",
        mixerInputErrorFormat: "Não foi possível trocar: %@",
        microphoneControlEnable: "Controle de entrada de áudio",
        mixerInputLevelLabel: "Nível de entrada",
        mixerInputSourceLabel: "Fonte de entrada de áudio",
        muteAudioInputSubtitle: "Silenciar entrada de áudio",
        manageAudioInputPriorityTitle: "Gerenciar preferência de entrada de áudio",
        manageAudioOutputPriorityTitle: "Gerenciar preferência de saída de áudio",
        mixerOutputLevelLabel: "Volume de saída",
        screenshotEnable: "Ativar captura de tela",
        screenRecorderEnable: "Ativar gravação de tela",
        audioPriorityOutputEnable: "Trocar automaticamente para a saída de áudio com maior prioridade",
        audioPriorityInputEnable: "Trocar automaticamente para o microfone de maior prioridade",
        audioPriorityOutputList: "Prioridade das saídas de áudio",
        audioPriorityInputList: "Prioridade dos microfones",
        audioPriorityMoveUp: "Mover para cima",
        audioPriorityMoveDown: "Mover para baixo",
        audioPriorityUnavailable: "Desconectado",
        audioPriorityCurrent: "Em uso",
        mixerOutputDeviceLabel: "Dispositivo de saída de áudio",
        mixerSystemSoundLabel: "Tocar sons do sistema em",
        mixerVolumeKeyStep: "Passo da tecla de volume",
        mixerVolumeKeyStepCaption: "Altera quanto cada toque na tecla ajusta o volume.",
        mixerVolumeKeyStepStandard: "Padrão",
        mixerVolumeKeyStepSmaller: "Menor",
        mixerAppVolumesTitle: "Volume dos apps",
        mixerShowInactiveAppsFormat: "Mostrar apps inativos (%d)",
        mixerHideInactiveApps: "Ocultar apps inativos",
        mixerOutputFollowSystem: "Padrão (seguir o sistema)",
        mixerAppVolumeFormat: "Volume de %@",
        audioPrioritySkipCycling: "Pular ao alternar",
        audioPrioritySetOutput: "Definir como saída de áudio",
        audioPrioritySetInput: "Definir como entrada de áudio",

        updatesSection: "Atualizações",
        betaBadgeLabel: "Beta",
        updateChecking: "Procurando…",
        updateUpToDate: "Você está na versão mais recente.",
        updateAvailablePrefix: "Atualização disponível:",
        updateInstallButton: "Baixar e instalar",
        updateDownloading: "Baixando atualização…",
        updateInstalling: "Instalando e reiniciando…",
        updateFailedPrefix: "Não foi possível verificar:",
        updateLastChecked: "Última verificação:",
        updateNotifyTitle: "Atualização do Lattice",
        updateInstallFailedBody: "A atualização foi baixada, mas não pôde ser aplicada. Baixe a versão mais recente na página de releases do GitHub e arraste o app por cima do atual.",
        updateNeedsApplicationsTitle: "Mova o Lattice para Aplicativos",
        updateNeedsApplicationsBody: "O app está rodando de um lugar que não dá para atualizar, como a imagem de disco ou uma área temporária do sistema. Arraste o Lattice para a pasta Aplicativos, abra de lá e tente de novo.",

        permissionRequired: "Permissão necessária",
        permissionAccessibility: "Controle de Dispositivos e Acesso a Dados",
        permissionScreenRecording: "Gravação de Tela",
        permissionGranted: "Concedida",
        permissionMissing: "Não concedida",
        permissionOpenSettings: "Abrir Ajustes do Sistema…",
        permissionRequest: "Conceder acesso",
        permissionRestartNote: "O macOS pode pedir para reabrir o app depois de conceder.",
        secureInputTitle: "A entrada segura está ativa",
        secureInputHeldFormat: "%@ está mantendo-a ativa, então o Lattice não consegue digitar por você. Saia do campo de senha do app, ou encerre-o, para liberá-la.",
        secureInputUnattributed: "Nenhum app em execução a reivindica. Encerre a sessão e entre novamente para limpá-la.",
        secureInputUnidentified: "Não foi possível identificar o app que a está mantendo ativa, então o Lattice não consegue digitar por você.",
        secureInputRevealFormat: "Mostrar %@",

        aboutDescription: "Central de utilidades para o seu Mac.\nEnergia, monitor do sistema, rolagem e alternador de janelas, direto na barra de menus.",
        versionPrefix: "Versão",
        navigationBack: "Voltar",
        releaseNotesFallback: "Esta atualização inclui as correções e melhorias mais recentes.",

        tabMonitor: "Monitor do Sistema",
        monitorSeparateMenuBarMetrics: "Mostrar leituras separadas",
        monitorSeparateMenuBarMetricsCaption: "Separa os blocos ativos na barra de menus e mantém uso e temperatura juntos quando combinar estiver ativo.",
        monitorNetworkUploadFirst: "Upload acima do download",
        monitorShowCPU: "CPU",
        monitorShowMemory: "Memória",
        monitorShowNetwork: "Rede",
        monitorShowPowerLabel: "Energia",
        betaBadge: "BETA",
        betaFeatureWarning: "Beta. Você pode encontrar alguns bugs.",

        networkSection: "Rede",
        networkApps: "Apps usando rede",
        networkAppsIdle: "Nenhum app usando rede agora",

        diskSection: "Discos",
        diskMenuBarStyleLabel: "Exibição do disco",
        diskMenuBarUsedPercentage: "Porcentagem usada",
        diskMenuBarAvailableSpace: "Espaço disponível",
        diskMenuBarUsedSpace: "Espaço usado",
        diskAvailable: "disponível",
        diskPurgeable: "purgável",
        diskStorageSettings: "Armazenamento",
        diskNoDisks: "Nenhum disco montado encontrado.",

        powerSection: "Energia",
        powerCharging: "Carregando",
        powerOnBattery: "Na bateria",
        powerPluggedIn: "Na tomada",
        powerUnavailable: "Métricas de energia indisponíveis neste Mac",
        powerAdapterMaxFormat: "%@ máx.",
        monitorShowGPU: "GPU",
        monitorShowCPUTemperature: "Temperatura da CPU",
        monitorShowGPUTemperature: "Temperatura da GPU",
        monitorShowBatteryTemperature: "Temperatura da bateria",
        monitorShowPeripheralBattery: SettingsFollowupStrings.text(.accessoryBattery, .ptBR),

        updateBannerTitle: "Atualização disponível",
        menuBarSpacingLabel: "Espaçamento na barra",
        menuBarSpacingStandard: "Padrão",
        menuBarSpacingCompact: "Compacto",
        monitorMemoryPressureDot: "Ponto de pressão",
        systemUptime: "Ativo há",
        powerCycles: "Ciclos",
        speedTestRun: "Testar velocidade",

        disclosureExpanded: "Expandido",
        disclosureCollapsed: "Recolhido",
        panelHiddenItem: "Oculto",
        monitorItemDiskUsage: "Uso do disco",
        monitorItemDiskActivity: "Atividade ao vivo",

        cleaningMenuItem: "Modo de limpeza",
        windowMaximizeName: "Maximizar janelas",
        windowMaximizeCaption: "Use os controles de janela do macOS para maximizar a janela sem movê-la para um Espaço em tela cheia separado.",
        keyDebounceName: "Proteção contra teclas duplicadas",
        keyDebounceEnable: "Ignorar digitação dupla",
        keyDebounceCaption: "Filtra toques duplicados muito rápidos.",
        keyDebounceGlobalWindow: "Intervalo do filtro de repetição",
        keyDebouncePerKeySection: "Teclas específicas",
        keyDebouncePerKeyCaption: "Valores por tecla substituem a janela global. Use 0 ms para não filtrar uma tecla.",
        keyDebounceKeyLabel: "Tecla",
        keyDebounceAddKey: "Adicionar tecla",
        keyDebounceRemoveKey: "Remover tecla",
        cleaningPanelCaption: "Bloqueia o teclado para limpar com segurança.",
        cleaningOverlayTitle: "Teclado bloqueado para limpeza",
        cleaningOverlaySubtitle: "Pressione Esc 5 vezes para desbloquear",
        cleaningOverlayUnlock: "Desbloquear",
        cleaningOverlayMouseHint: "O mouse e o trackpad continuam funcionando",
        cleaningNeedsAxTitle: "Precisa de Acessibilidade",
        cleaningNeedsAxBody: "Para bloquear o teclado com segurança, o Lattice precisa da permissão de Acessibilidade. Conceda em Ajustes do Sistema e tente de novo.",
        shortcutsPageTitle: "Atalhos de teclado",
        settingsSearchPlaceholder: "Buscar ajustes",
        doneButton: "Concluir",
        homebrewOfficialIntroTitle: "Agora no catálogo oficial do Homebrew",
        homebrewOfficialIntroMessage: "O Lattice agora pode ser instalado direto do catálogo oficial do Homebrew.",
        homebrewOfficialIntroInstallLabel: "Nova instalação",
        homebrewOfficialIntroMigrationTitle: "Usava o tap antigo?",
        homebrewOfficialIntroMigrationMessage: "Remova o tap uma vez. O app e seus ajustes continuam no lugar.",
        homebrewOfficialIntroCopyButton: "Copiar comando",
        shortcutRecording: "Pressione o novo atalho",
        shortcutReset: "Redefinir",
        shortcutNone: "Nenhum",
        shortcutClear: "Remover atalho",
        shortcutInvalid: "Use pelo menos Control, Option ou Command junto com uma tecla.",
        shortcutPressKeys: "Pressione",
        shortcutEscapeHint: "Esc cancela.",
        shortcutDeleteHint: "Delete remove.",
        shortcutConflictFormat: "Este atalho já está em uso por %@.",
        shortcutTakeOverOffer: "O macOS usa %@ em um atalho próprio.",
        shortcutTakeOverAction: "Assumir enquanto o Lattice estiver aberto",
        shortcutTakeOverCaption: "O macOS recupera a tecla sempre que o Lattice não estiver aberto ou este recurso estiver desligado.",
        shortcutTakeOverDismiss: "Não assumir",
        shortcutUnavailable: "O macOS recusou este atalho. Escolha outro.",
        musicBlockSection: "Desativar tecla de mídia",
        musicBlockTitle: "Impedir que o Música abra sozinho",
        musicBlockCaption: "Impede que a tecla de mídia abra o app de música padrão",
        musicBlockUnavailable: "Esta proteção está indisponível agora. Desligue e ligue a opção para tentar novamente.",
        musicBlockPlayReplacement: "Reproduzir após abrir o app substituto",
        cleanerName: "Limpeza",
        cleanerIntroTitle: "Limpe o lixo do Mac",
        cleanerIntroCaption: "Procura restos de apps desinstalados, caches, registros e a Lixeira. Você revisa tudo antes e os itens removidos vão para a Lixeira.",
        cleanerScan: "Verificar",
        cleanerScanning: "Verificando…",
        cleanerCleaning: "Limpando…",
        cleanerCatLeftovers: "Restos de apps desinstalados",
        cleanerCatLoginItems: "Itens de início órfãos",
        cleanerCatCaches: "Caches",
        cleanerCatLogs: "Registros",
        cleanerCatDeveloper: "Lixo de desenvolvimento",
        cleanerCatTrash: "Lixeira",
        cleanerLeftoversNote: "Encontrados por análise e começam desmarcados. Confira o caminho antes de marcar.",
        cleanerLoginItemsNote: "A entrada em Itens de Início some depois de reiniciar o Mac.",
        cleanerTrashNote: "Esvaziar a Lixeira é permanente.",
        cleanerCatDeviceBackups: "Backups de iPhone",
        cleanerDeviceBackupsCaption: "Backups antigos de iPhone e iPad ocupam boa parte do que o macOS chama de Outros. Remova só os que você não precisa mais; um novo backup é feito quando o aparelho for conectado de novo.",
        cleanerCatScreenshots: "Capturas de tela esquecidas",
        cleanerScreenshotsCaptionFormat: "Capturas de tela que você não abre há %d dias e que ainda têm o nome e a pasta que o macOS deu. As que você renomeou ou moveu nunca aparecem aqui.",
        cleanerScreenshotsSettingCaption: "A varredura lista, desmarcadas e com o tamanho total, as capturas de tela que você não abre há esse tempo.",
        cleanerScreenshotsAfterFormat: "Após %d dias",
        cleanerNothingFound: "Nada para limpar. Seu Mac está em ordem.",
        cleanerDoneNote: "Os itens foram para a Lixeira e podem ser recuperados de lá.",
        cleanerAgain: "Verificar de novo",
        cleanerRevealInFinder: "Mostrar no Finder",
        cleanerSafeSection: "Limpeza segura",
        cleanerOptionalSection: "Opcional, revise antes",
        cleanerCatOtherCaches: "Outros caches",
        cleanerCachesCaption: "Arquivos temporários que os apps refazem sozinhos.",
        cleanerLogsCaption: "Registros antigos de diagnóstico.",
        cleanerDeveloperCaption: "Restos de compilações e simuladores do Xcode.",
        cleanerLoginItemsCaption: "Entradas de início deixadas por apps que não existem mais.",
        cleanerLeftoversCaption: "Arquivos deixados por apps que você desinstalou.",
        cleanerOtherCachesCaption: "Seguro apagar, nada quebra. Apps podem abrir mais devagar na primeira vez e conteúdo baixado, como músicas offline, baixa de novo.",
        cleanerCleanSizeFormat: "Limpar %@",
        cleanerScheduleTitle: "Limpeza automática",
        cleanerScheduleOff: "Desativada",
        cleanerScheduleDaily: "Diária",
        cleanerScheduleWeekly: "Semanal",
        cleanerScheduleCaption: "Limpa sozinha só a parte segura no horário escolhido e manda tudo para a Lixeira.",
        cleanerScheduleLastFormat: "A última limpeza automática liberou %@.",
        cleanerAutoNotificationFormat: "%@ liberados e enviados para a Lixeira.",
        cleanerScheduleNextFormat: "Próxima limpeza %@.",
        cleanerScheduleRanFormat: "Última limpeza automática %@.",
        cleanerScheduleNotifyToggle: "Avisar quando terminar",
        cleanerNotifDenied: "As notificações do Lattice estão desativadas no sistema.",
        cleanerNotifOpenSettings: "Abrir Ajustes de Notificações…",
        launchAtLoginNeedsApplications: "O app está rodando de um lugar que não permite abrir no login. Arraste o Lattice para a pasta Aplicativos, abra de lá e ligue de novo.",
        launchAtLoginNeedsApproval: "O item de login está registrado, mas o macOS ainda precisa da sua aprovação. Nos Ajustes do Sistema, permita que o Lattice abra no login e funcione em segundo plano.",
        ocrRemoveLineBreaksToggle: "Remover quebras de linha",
        ocrRemoveLineBreaksCaption: "Remove as quebras de linha para que o texto copiado seja colado como um único parágrafo.",
        ocrQRToggle: "Ler QR codes",
        ocrQRCaption: "Se a área tiver um QR code, o conteúdo dele aparece para copiar ou abrir.",
        ocrQRCopied: "QR code copiado",
        qrResultTitle: "QR code",
        qrResultCopy: "Copiar",
        qrResultOpen: "Abrir link",
        switcherCurrentSpaceOnly: "Mostrar apenas janelas da mesa atual",
        switcherCurrentSpaceOnlyCaption: "Mostra as janelas da Mesa atual. Janelas em tela cheia de outras Mesas também aparecem enquanto “Mostrar janelas em tela cheia” estiver ativo.",
        shelfFileMissing: "O arquivo não existe mais",
        previewSizeSmall: "Pequeno",
        mixerSoundEffectsOutputTitle: "Sons do sistema",
        mixerSoundEffectsOutputTooltip: "Escolher onde alertas e efeitos sonoros tocam",
        monitorOpenActivityMonitor: "Abrir o Monitor de Atividade",
        dockClickHide: "Clicar no Dock oculta o app",
        dockClickHideCaption: "O app ativo é ocultado ao clicar no ícone dele no Dock. Clique de novo para trazê-lo de volta.",
        urlCleanerRemovedFormat: "Removidos %@",
        switcherSearchPlaceholder: "Buscar",
        invertVerticalScroll: "Inverter rolagem vertical",
        invertHorizontalScroll: "Inverter rolagem horizontal",
        scrollHorizontalName: "Rolar na horizontal segurando uma tecla",
        scrollHorizontalModifierLabel: "Tecla modificadora",
        scrollHorizontalCommandKey: "Command",
        scrollHorizontalCaption: "Segure a tecla escolhida ao usar a roda do mouse para rolar na horizontal.",
        switcherShowShortcutHints: "Mostrar dicas de atalhos",
        switcherShowShortcutHintsCaption: "Exibe os atalhos de apps e janelas abaixo dos ícones.",
        uninstallerHomebrewPackageFormat: "%@ também será removido do Homebrew.",
        uninstallerHomebrewCheckFailed: "Não foi possível verificar se o Homebrew gerencia este aplicativo. Atualize para tentar novamente ou desinstale pelo Homebrew.",
        shelfEdgeToggle: "Abrir perto de uma borda da tela",
        shelfEdgeCaption: "Ao arrastar um arquivo para perto da borda da tela, a área espia para dentro. Solte ali, ou puxe de volta e ela recua.",
        focusFollowsMouseName: "Foco ao passar o mouse",
        focusFollowsMouseCaption: "Coloca em foco a janela sob o ponteiro.",
        focusFollowsMouseDelay: "Atraso ao passar o mouse",
        focusFollowsMouseRaise: "Trazer a janela para frente",
        focusFollowsMouseWaitForStop: "Esperar o ponteiro parar",
        switcherMinimizedPlacementLabel: "Mostrar janelas minimizadas",
        switcherMinimizedPlacementNormal: "Na ordem recente",
        switcherMinimizedPlacementEnd: "Depois das outras janelas",
        switcherMinimizedPlacementHidden: "Nunca",
        switcherShowFullscreenWindows: "Mostrar janelas em tela cheia",
        switcherScreenPlacementLabel: "Mostrar alternador em",
        switcherScreenPlacementPointer: "Tela com o mouse",
        switcherScreenPlacementMenuBar: "Tela principal",
        switcherScreenPlacementActiveWindow: "Tela com a janela ativa",
        switcherCurrentDisplayOnly: "Mostrar apenas janelas da tela atual",
        switcherCurrentDisplayOnlyCaption: "Mostra apenas as janelas da tela sob o cursor. Se essa tela não tiver janelas, o alternador não abre.",
        smoothScrollResponseLabel: "Resposta",
        smoothScrollCoastLabel: "Inércia",
        mouseAccelerationName: "Desativar aceleração do ponteiro",
        mouseAccelerationCaption: "O ponteiro segue a distância da mão, não a velocidade.",
        linearScrollName: "Rolagem linear",
        linearScrollCaption: "Cada passo da rodinha do mouse rola a mesma distância, não importa a velocidade do giro. O trackpad não muda.",
        linearScrollLinesLabel: "Linhas por passo",
        scrollSpeedName: "Rolar mais rápido segurando uma tecla",
        scrollSpeedCaption: "Segure a tecla escolhida ao usar a roda do mouse para rolar mais rápido.",
        scrollSpeedMultiplierLabel: "Velocidade",
        shelfClearOnClose: "Limpar ao fechar",
        shelfClearOnCloseCaption: "Esvazia a área somente quando você clica no botão de fechar. Ocultar automaticamente e encolher preservam os itens.",
        shelfShortcutFinderSelection: "Adicionar a seleção do Finder com o atalho",
        shelfShortcutFinderSelectionCaption: "Com o Finder em primeiro plano, o atalho abre a área temporária já com os arquivos selecionados. Sem seleção, ela abre como sempre.",
        spacesOrderName: "Manter os Espaços em ordem fixa",
        spacesOrderCaption: "Impede que o macOS reorganize os Espaços pelo uso mais recente, para que fiquem na ordem que você definiu. A configuração anterior volta ao desligar esta opção. O Dock pode reiniciar uma vez para aplicar a mudança."
    )
}

// MARK: - English (US)

extension Strings {
    static let enUS = Strings(
        menuEnableAwake: "Enable keep awake",
        menuDisableAwake: "Disable keep awake",
        menuSettings: "Settings…",
        menuAbout: "About Lattice",
        menuQuit: "Quit Lattice",
        menuHide: "Hide Lattice",
        menuHideOthers: "Hide Others",
        menuShowAll: "Show All",
        menuEdit: "Edit",
        menuUndo: "Undo",
        menuRedo: "Redo",
        actionClear: "Clear",
        actionMute: "Mute",
        actionUnmute: "Unmute",
        actionPause: "Pause",
        menuCut: "Cut",
        menuCopy: "Copy",
        menuPaste: "Paste",
        menuSelectAll: "Select All",
        menuWindow: "Window",
        menuMinimize: "Minimize",
        menuZoom: "Zoom",
        menuClose: "Close",

        minutes15: "15 minutes",
        minutes30: "30 minutes",
        hour1: "1 hour",
        hours2: "2 hours",
        hours4: "4 hours",
        hours8: "8 hours",
        indefinitely: "Indefinitely",
        indefinite: "Indefinite",

        panelQuit: "Quit",

        keepAwakeTitle: "Stay Awake",
        keepAwakeEndsIn: "Ends in",
        keepAwakeUntilDisabled: "Active until you turn it off",

        temperatures: "Temperatures",
        cpuLabel: "CPU",
        gpuLabel: "GPU",
        batteryLabel: "Battery",
        memorySection: "Memory",
        memoryPressure: "Pressure",
        memorySwapUsed: "Swap used",
        memoryCompressed: "Compressed",
        memoryCachedFiles: "Cached files",
        pressureNormal: "Normal",
        pressureWarning: "Caution",
        pressureCritical: "Critical",
        monitorUnavailable: "Sensors unavailable on this Mac",
        energyAppsIdle: "No significant energy use",

        notifySessionEndedTitle: "Session ended",
        notifySessionEndedBody: "Time is up. The Mac will sleep normally again.",
        notifyBatteryTitle: "Lattice disabled",
        notifyBatteryBody: "Low battery. Normal sleep was restored to protect the charge.",
        adminPromptClamshellOff: "Lattice needs your password to restore the Mac’s normal sleep.",
        adminPromptRecover: "Lattice quit while the Mac’s sleep was disabled. Enter the password to restore normal sleep.",
        adminPromptUpdate: "Lattice needs your password to install the update.",
        adminPromptSudoersInstall: "Lattice will create a restricted rule (pmset disablesleep only) to toggle closed-lid mode without asking for a password. This is the only time the password is needed.",
        adminPromptSudoersRemove: "Lattice will remove the password-free closed-lid rule.",

        settingsTitle: "Lattice Settings",
        tabGeneral: "General",
        tabEnergy: "Energy",
        tabMouse: "Mouse & Trackpad",
        tabSwitcher: "App Switcher",
        tabAbout: "About",
        tabReleaseNotes: "What’s New",
        minimalWindowPreviews: "Hide preview title and controls",
        minimalWindowPreviewsCaption: "Only show window preview and hide title and controls.",
        previewSizeLabel: "Preview size",
        previewSizeNormal: "Normal",
        previewSizeLarge: "Large",
        previewSizeXLarge: "Extra large",
        advancedClearButton: "Clear all permissions",
        advancedClearFailed: "Reset incomplete. Input controls remain paused. Restart Lattice and review permissions and Login Items in System Settings.",
        advancedUninstallDescription: "Remove Lattice and its settings from your Mac.",
        advancedUninstallButton: "Uninstall Lattice",
        advancedUninstallConfirmTitle: "Uninstall Lattice?",
        advancedUninstallConfirmBody: "The Lattice app will move to the Trash. Its settings and app-owned data will be permanently deleted and cannot be recovered from the Trash.",
        advancedUninstallFailedTitle: "Uninstall stopped",
        advancedUninstallFailedBody: "Lattice could not put back a system setting it changed: sleep, fan speed, mouse acceleration or Space order. Nothing was removed. Try again and allow the password request if it appears.",

        launchAtLogin: "Launch at login",
        languageLabel: "Language",
        hotkeyToggle: "Enable shortcut for “Keep awake”",

        batteryNever: "Never",
        configuring: "Configuring…",
        sudoersFailed: "Couldn’t turn on closed-lid mode. Try again.",

        invertMouseScroll: "Invert mouse scrolling",
        scrollTrackpadNote: "Applies to the mouse wheel. Trackpad scrolling stays unchanged.",
        smoothScrollName: "Smooth scrolling",
        smoothScrollCaption: "Smooths mouse-wheel scrolling. Trackpad scrolling stays unchanged.",
        smoothScrollStepLabel: "Scrolling speed",
        mouseNavigationEnable: "Side Button Navigation",
        middleClickSection: "Trackpad Gestures",
        middleClickEnable: "Middle-click gesture",
        middleClickEnableCaption: "Trigger mouse middle-click actions with trackpad.",
        middleClickNoTrackpad: "Can’t read trackpad touches. Connect a supported trackpad.",
        middleClickTapPicker: "Tap with",
        middleClickTapOff: "Off",
        middleClickTapThreeFingers: "3 fingers",
        middleClickTapFourFingers: "4 fingers",
        middleClickTapCaption: "Tap without pressing to middle-click. Turn off the matching macOS Look Up gesture to avoid conflicts.",
        ocrName: "Copy text from screen",
        ocrCaption: "Select an area of the screen and the recognized text is copied, ready to paste.",
        ocrCopied: "Text copied",
        ocrNoText: "No text found",
        colorPickerName: "Color picker",
        colorPickerCaption: "Grab the color of any pixel on screen and copy it in your favorite format.",
        micMuteName: "Mute Microphone",
        micUnmuteName: "Unmute Microphone",
        micMuteCaption: "Cuts the Mac’s microphone with a click or shortcut, across every app.",
        micMuteFollowCallAppsToggle: "Allow call apps to unmute the microphone",
        micMuteFollowCallAppsCaption: "If a microphone reopens while an app is recording from it, Lattice restores every microphone it muted. A call app’s automatic volume adjustment can also do this.",
        micMutedHUD: "Muted",
        micUnmutedHUD: "Unmuted",
        micMutePartialHUD: "Some microphones could not be muted",
        micUnmutePartialHUD: "Some microphones are still muted",
        micMuteMenuBarToggle: "Show mute status in menu bar",
        pastePlainName: "Paste as plain text",
        pastePlainCaption: "Pastes what you copied without colors, fonts or formatting. The original stays on the clipboard.",
        launcherName: "Lattice Hub",

        switcherSection: "App Switcher",
        switcherNoWindows: "No open windows",
        switcherIconRowMode: "Show %@ with large icons",
        switcherIconRowModeCaption: "Shows one icon per app with that app’s window previews above it.",
        switcherSimpleModeCaption: "Shows app icons and window titles, without previews or screen capture by the switcher.",
        switcherShortcutHintApps: "Apps",
        switcherShortcutHintWindows: "Windows",
        switcherAppearanceDelay: "Hold delay",
        switcherAppearanceDelayCaption: "How long the shortcut must be held before the switcher appears.",
        switcherMaxColumns: "Maximum columns",
        switcherMaxColumnsCaption: "Wraps onto more rows after this many items. Useful on ultrawide displays.",
        switcherMaxColumnsAuto: "Auto",
        switcherInstantSelection: "Instant selection",
        switcherIgnoreHoverSelection: "Ignore hover selection",
        switcherMergeTabs: "Group windows by app",
        switcherMergeTabsCaption: "One entry per app instead of one per window.",
        switcherWindowlessApps: "Hide apps without windows",
        switcherWindowlessAppsFinder: "Don’t hide Finder",
        switcherNoOpenWindow: "No open window",
        switcherOtherDesktop: "Other desktop",
        dockPreviewName: "Dock Preview",
        dockPreviewEnable: "Enable Dock Preview",
        dockPreviewCurrentSpaceOnly: "Only show windows from current desktop",
        dockPreviewCurrentSpaceOnlyCaption: "Hide windows from other desktops.",
        dockPreviewCurrentSpaceOnlyInfo: "Selecting a window on another desktop automatically switches to it.",
        dockPreviewBackgroundOpacity: "Panel background",
        dockPreviewBackgroundOpacityCaption: "Turn it down to see more of what sits behind the panel.",
        dockPreviewBackgroundOpacityGlassCaption: "Liquid Glass is on, so the panel’s transparency is set in System Settings > Appearance.",
        dockPreviewOpenDelay: "Hover delay",
        dockPreviewOpenDelayCaption: "Delay before showing previews when pointing at an icon.",
        dockPreviewDelayDefault: "Default",
        dockPreviewDelayLonger: "Longer",
        dockPreviewQuitApplication: "Quit application",
        dockPreviewKeepDockVisible: "Keep Dock visible during preview",
        dockPreviewKeepDockVisibleCaption: "Prevents the Dock from hiding while previews are open.",
        dockPreviewOrderByCreation: "Show oldest windows first",
        dockPreviewOrderByCreationCaption: "List windows in the order they were opened rather than by recent activity.",
        dockClickMinimize: "Click the dock tile to minimize",
        dockClickCycleWindows: "Click the dock tile to cycle windows",
        dockPreviewDockUnavailable: "Could not read Dock items.",
        dockPreviewOpenWindow: "Open window",
        dockPreviewCloseWindow: "Close window",
        dockPreviewMinimizeWindow: "Minimize window",
        dockPreviewRestoreWindow: "Restore window",
        dockPreviewPinPanel: "Pin preview",
        dockPreviewUnpinPanel: "Unpin preview",
        dockPreviewPinned: "Pinned",
        dockPreviewClosePanel: "Close preview",
        dockPreviewPreviousWindow: "Previous window",
        dockPreviewNextWindow: "Next window",

        finderAutomationNote: "The first time, macOS asks for permission to control Finder.",

        autoQuitName: "Quit Inactive Apps",
        autoQuitEnable: "Quit an app when its last window closes",
        autoQuitEnableCaption: "Quit apps when the last window is closed",
        autoQuitExceptionsTitle: "Exceptions",

        uninstallerName: "Uninstaller",
        uninstallerChoose: "Choose app…",
        uninstallerPickerTitle: "Choose app",
        uninstallerPickerSearch: "Search apps",
        uninstallerPickerEmpty: "No apps found",
        uninstallerFDANote: "Grant Full Disk Access for a more thorough scan.",
        uninstallerFDAGrant: "Grant access…",
        uninstallerFDAHint: "Turn Lattice on in the list. If it isn’t there, click + and pick Lattice from Applications. Access only applies after you reopen the app.",
        uninstallerFDARelaunch: "Relaunch now",
        uninstallerScanning: "Scanning files…",
        uninstallerRemoving: "Moving to the Trash…",
        uninstallerFoundTitle: "found",
        uninstallerSelectedFormat: "%d of %d selected",
        uninstallerSelectAll: "Select all",
        uninstallerRemove: "Move to Trash",
        uninstallerCancel: "Cancel",
        uninstallerConfirmationExpired: "This confirmation is no longer valid. Review the current items and confirm again.",
        uninstallerDoneTitle: "Done!",
        uninstallerFreedFormat: "%@ removed",
        uninstallerSomeFailed: "Some items couldn’t be moved to the Trash.",
        uninstallerFailedNeedsFDA: "Sandboxed app data can only be moved with Full Disk Access. The administrator password does not stand in for it.",
        uninstallerFailedMoreFormat: "and %d more",
        uninstallerAnother: "Uninstall another",
        uninstallerCatApp: "Application",
        uninstallerCatSupport: "Support",
        uninstallerCatCaches: "Caches",
        uninstallerCatPreferences: "Preferences",
        uninstallerCatContainers: "Containers",
        uninstallerCatLogs: "Logs",
        uninstallerCatState: "Saved state",
        uninstallerCatOther: "Other",
        uninstallerCommandBarBrowseTitle: "Uninstall Application",
        uninstallerCommandBarFinderTitle: "Uninstall app selected in Finder",
        uninstallerSelectionUnavailable: "Select an app that can be removed in Finder, or choose another from the list.",

        urlCleanerName: "URL Sanitizer",
        urlCleanerActiveNow: "Active now",
        urlCleanerManualTitle: "Clean now",
        urlCleanerInputPlaceholder: "Paste a URL",
        urlCleanerOutputPlaceholder: "The clean URL appears here",
        urlCleanerPasteButton: "Paste",
        urlCleanerCopyButton: "Copy",
        urlCleanerClearButton: "Clear field",
        urlCleanerNoURL: "Paste a valid URL.",
        urlCleanerNoChange: "Nothing to clean.",
        urlCleanerCleaned: "URL cleaned.",
        urlCleanerCopied: "Copied.",

        homebrewName: "Homebrew",
        homebrewMissingTitle: "Homebrew not found",
        homebrewMissingBody: "Lattice can open the official Homebrew installer in your terminal. It shows the steps and asks for your password if needed.",
        homebrewInstallHomebrew: "Install Homebrew",
        homebrewInstallHomebrewCaption: "When the installer finishes, come back here and click Refresh.",
        homebrewInstallHomebrewOpened: "Installer opened in your terminal.",
        homebrewShellSetupTitle: "Finish terminal setup",
        homebrewShellSetupBody: "Homebrew is installed, but your terminal may not find the brew command yet. Lattice can open the setup command in your terminal.",
        homebrewShellSetupButton: "Set up terminal",
        homebrewShellSetupOpened: "Command opened in your terminal. Then come back here and click Refresh.",
        homebrewRefresh: "Refresh",
        homebrewTrustTitle: "Tap not trusted yet",
        homebrewTrustCaption: "Homebrew now asks for your confirmation before using third party taps. Trust %@ to continue.",
        homebrewTrustButton: "Trust and continue",
        homebrewInstalled: "Installed",
        homebrewAll: "All",
        homebrewNoPackages: "No packages found",
        homebrewGroupDependencies: "Group dependencies",
        homebrewInstall: "Install",
        homebrewUninstall: "Uninstall",
        homebrewUpgrade: "Update",
        homebrewUpgradeAll: "Update all",
        homebrewUpdateHomebrew: "Update Homebrew",
        homebrewAllPackages: "packages",
        homebrewOpenTerminal: "Open terminal",
        homebrewCancelOperation: "Cancel",
        homebrewClearLog: "Clear log",
        homebrewHomepage: "Open website",
        homebrewPopularityFormat: "%@ installs in %@ days",
        homebrewInstalledBadge: "Installed",
        homebrewConfirmInstallBodyFormat: "Homebrew will download and install %@. Dependencies may also be installed.",
        homebrewConfirmUninstallTitle: "Uninstall with Homebrew?",
        homebrewConfirmUninstallBodyFormat: "Homebrew will uninstall %@. Configuration files may remain on the system.",
        homebrewConfirmUpgradeBodyFormat: "Homebrew will download and apply the latest version of %@. Dependencies may also be updated.",
        homebrewConfirmUpgradeAllTitle: "Update all with Homebrew?",
        homebrewConfirmUpgradeAllBody: "Homebrew will download and apply the latest versions for packages with updates available. Dependencies may also be updated.",
        homebrewConfirmUpdateHomebrewTitle: "Update Homebrew?",
        homebrewConfirmUpdateHomebrewBody: "Homebrew will fetch the latest information and then reload your packages.",
        homebrewTerminalFallback: "This operation needs your terminal to ask for the administrator password. Lattice does not capture passwords.",
        homebrewLoading: "Loading…",
        homebrewOperationInstallFormat: "Installing %@",
        homebrewOperationUninstallFormat: "Uninstalling %@",
        homebrewOperationUpgradeFormat: "Updating %@",
        homebrewOperationUpgradeAll: "Updating packages",
        homebrewOperationUpdateHomebrew: "Updating Homebrew",
        homebrewOperationInstalledFormat: "%@ installed.",
        homebrewOperationUninstalledFormat: "%@ uninstalled.",
        homebrewOperationUpgradedFormat: "%@ updated.",
        homebrewOperationUpgradedAll: "Packages updated.",
        homebrewOperationUpdatedHomebrew: "Homebrew updated.",
        homebrewOperationFailedFormat: "Could not finish %@.",
        homebrewOperationCancelled: "Operation cancelled.",
        homebrewOperationPreparing: "Preparing…",
        homebrewOperationDownloading: "Downloading files…",
        homebrewOperationInstalling: "Installing files…",
        homebrewOperationUninstalling: "Removing files…",
        homebrewOperationUpgrading: "Updating files…",
        homebrewOperationFinalizing: "Finishing…",
        homebrewOperationRefreshing: "Refreshing list…",
        homebrewOperationTerminal: "Continue in your terminal.",
        homebrewOperationElapsedFormat: "%@ elapsed",
        homebrewOperationShowDetails: "Show details",
        homebrewOperationHideDetails: "Hide details",
        homebrewOperationTechnicalLog: "Technical details",
        homebrewOperationProgressUnknown: "Homebrew has not reported a percentage yet.",

        mediaName: "Media Compression",
        mediaLocalNote: "Local. No network.",
        mediaToolVideo: "Video",
        mediaToolGIF: "GIF",
        mediaToolImage: "Image",
        mediaToolText: "Text",
        mediaSelectFile: "Choose file",
        mediaDropHint: "Drop a file here or click to choose one.",
        mediaOutput: "Output",
        mediaOutputAutomatic: "Automatic",
        mediaChooseOutput: "Destination",
        mediaStartVideo: "Compress video",
        mediaStartGIF: "Make GIF",
        mediaStartImage: "Process image",
        mediaStartConvertPDF: "Convert to PDF",
        mediaStartText: "Extract text",
        mediaCancel: "Cancel",
        mediaStartTime: "Start",
        mediaEndTime: "End",
        mediaQuality: "Compression",
        mediaCompressionLow: "Low",
        mediaCompressionMedium: "Medium",
        mediaCompressionHigh: "High",
        mediaCompressionLowDescription: "High quality, large file size",
        mediaCompressionMediumDescription: "Balanced quality and file size",
        mediaCompressionHighDescription: "Low quality, small file size",
        mediaMaxSize: "Size",
        mediaSizingResolution: "Resolution",
        mediaSizingFileSize: "File size",
        mediaTargetSize: "Target size",
        mediaTargetSizeHint: "Resolution adapts to stay under the limit.",
        mediaErrorTargetTooSmall: "Target size too small for this clip. Trim it or raise the limit.",
        mediaMegabytesSuffix: " MB",
        mediaWidth: "Width",
        mediaFPS: "FPS",
        mediaFormat: "Format",
        mediaStripMetadata: "Remove metadata",
        mediaLoopGIF: "Loop GIF",
        mediaOCRMode: "OCR",
        mediaOCRAccurate: "Accurate",
        mediaOCRFast: "Fast",
        mediaRunning: "Processing",
        mediaCompleted: "Done",
        mediaCancelled: "Cancelled.",
        mediaOpenInFinder: "Show",
        mediaCopyText: "Copy text",
        mediaRunAgain: "Run again",
        mediaEmptyText: "No text found.",
        mediaResultSavedFormat: "Saved as %@",
        mediaResultSizeFormat: "%@ to %@",
        mediaResultGrewCaption: "The converted file came out larger than the original.",
        mediaErrorNoFile: "Choose a file first.",
        mediaErrorNoVideo: "This file has no video track.",
        mediaErrorSameOutput: "Choose a destination different from the original file.",
        mediaErrorUnsupported: "Format not supported by macOS.",

        shelfName: SettingsOwnershipStrings.text(.fileCache, .enUS),
        shelfEnable: "Temporary area for dragging files",
        shelfShakeToggle: "Open by shaking the mouse while dragging",
        shelfShakeCaption: "Shake the pointer quickly while holding an item to summon it near the cursor.",
        shelfDropZoneToggle: "Keep dragged files in the menu bar",
        shelfDropZoneCaption: "While you drag a file, the File Cache appears below the menu bar icon. Whatever you drop is kept right there, in a button you shrink and open with a click that goes away once the File Cache is empty.",
        shelfDropZoneCaptionTopCenter: "While you drag a file, the File Cache appears as a badge at the top center of the screen. Whatever you drop is kept right there, in a badge you open with a click that goes away once the File Cache is empty.",
        shelfDockPlacement: "Position",
        shelfDockMenuBar: "Below the menu bar icon",
        shelfDockTopCenter: "Top center of the screen",
        shelfDockIslandNote: "The Dynamic Island keeps the top center while it is on.",
        shelfCollapse: "Collapse",
        shelfBehaviorTitle: "After use",
        shelfCloseAfterDrop: "Close after dropping into another app",
        shelfCloseAfterDropCaption: "Closes the File Cache when the destination accepts the items. The pin in the panel keeps it open.",
        shelfRemoveAfterDrop: "Remove items after dropping",
        shelfRemoveAfterDropCaption: "Items accepted by another app leave the File Cache. Turn this off to keep a copy there. Pinned items always stay.",
        shelfExclusionsTitle: "Automatic exceptions",
        shelfExclusionsEmpty: "No apps added.",
        shelfExclusionsCaption: "Shake and the menu bar drop zone stay off for drags started in these apps. The shortcut and Open now still work.",
        shelfPin: "Keep open",
        shelfUnpin: "Allow closing after use",
        extraBrightnessName: "Extra brightness",
        extraBrightnessCaption: "Uses the display’s HDR headroom to go past the maximum brightness. Uses more battery and the Mac can run warm.",
        extraBrightnessLevelLabel: "Intensity",
        extraBrightnessUnsupported: "Available only on XDR displays, such as the ones on the 14 and 16 inch MacBook Pro.",
        shelfOpenNow: "Open now",
        shelfTitle: SettingsOwnershipStrings.text(.fileCache, .enUS),
        shelfEmpty: "Drag items here",
        shelfClearAll: "Clear all",
        shelfRemoveSelected: "Remove selected",
        shelfSelectedFormat: "%d selected",
        shelfHint: "Click to select. Drag out to use or right-click for more actions.",
        shelfItemImage: "Image",
        shelfTooltipItemsFormat: "%d items",
        shelfTooltipItemsFew: "%d items",
        shelfTooltipImageSingular: "%d image",
        shelfTooltipImageFew: "%d images",
        shelfTooltipImagePlural: "%d images",
        shelfTooltipFileSingular: "%d file",
        shelfTooltipFileFew: "%d files",
        shelfTooltipFilePlural: "%d files",
        shelfTooltipNoteSingular: "%d note",
        shelfTooltipNoteFew: "%d notes",
        shelfTooltipNotePlural: "%d notes",
        shelfTooltipLinkSingular: "%d link",
        shelfTooltipLinkFew: "%d links",
        shelfTooltipLinkPlural: "%d links",
        shelfActionOpen: "Open",
        shelfActionOpenWith: "Open With",
        shelfActionShare: "Share",
        shelfActionPin: "Pin",
        shelfActionUnpin: "Unpin",

        breakdownMeasuring: "Measuring…",

        mixerSection: "Volume Mixer",
        mixerEmpty: "Apps that use audio show up here",
        mixerUnavailable: "Available on macOS 14.4 and later",
        mixerPermissionBody: "To adjust per-app volume, allow “Screen & System Audio Recording” in System Settings. Audio is never recorded.",
        mixerOutputDefault: "Default",
        mixerOutputUnavailable: "Output unavailable",
        mixerBypassedCaption: "This app manages its own audio.",
        mixerSystemOutputTitle: "Output",
        mixerSystemOutputNoDevices: "No outputs found",
        mixerLowerOnHeadphonesDisconnect: "Lower volume when headphones disconnect",
        mixerLowerOnHeadphonesDisconnectCaption: "Adjusts output when wired or Bluetooth headphones disconnect.",
        mixerHeadphonesDisconnectVolume: "Volume after disconnect",
        volumeMixerEnable: "Audio Output Control",
        preciseVolumeRollerTapFailed: "Could not listen for volume keys.",
        soundOutputSwitcherTitle: "Output switcher",
        soundOutputSwitcherEnable: "Cycle through with shortcut",
        soundOutputSwitcherCaption: "Use the shortcut to cycle through output devices.",
        mixerInputTitle: "Microphone",
        mixerInputNoDevices: "No microphones found",
        mixerInputUnavailable: "Microphone unavailable",
        mixerInputTooltip: "Choose microphone",
        mixerInputErrorFormat: "Could not switch: %@",
        microphoneControlEnable: "Audio Input Control",
        mixerInputLevelLabel: "Input Level",
        mixerInputSourceLabel: "Audio input source",
        muteAudioInputSubtitle: "Mute Audio Input",
        manageAudioInputPriorityTitle: "Manage Audio Input Preference",
        manageAudioOutputPriorityTitle: "Manage Audio Output Preference",
        mixerOutputLevelLabel: "Output volume",
        screenshotEnable: "Enable Screenshot",
        screenRecorderEnable: "Enable Screen Recording",
        audioPriorityOutputEnable: "Automatically switch to the highest-priority output",
        audioPriorityInputEnable: "Automatically switch to the highest-priority microphone",
        audioPriorityOutputList: "Output priority",
        audioPriorityInputList: "Microphone priority",
        audioPriorityMoveUp: "Move up",
        audioPriorityMoveDown: "Move down",
        audioPriorityUnavailable: "Disconnected",
        audioPriorityCurrent: "Current",
        mixerOutputDeviceLabel: "Audio output device",
        mixerSystemSoundLabel: "Play system sound at",
        mixerVolumeKeyStep: "Volume key step",
        mixerVolumeKeyStepCaption: "Changes how much each key press adjusts volume.",
        mixerVolumeKeyStepStandard: "Standard",
        mixerVolumeKeyStepSmaller: "Smaller",
        mixerAppVolumesTitle: "App Volumes",
        mixerShowInactiveAppsFormat: "Show inactive apps (%d)",
        mixerHideInactiveApps: "Hide inactive apps",
        mixerOutputFollowSystem: "Default (Follow System)",
        mixerAppVolumeFormat: "%@ volume",
        audioPrioritySkipCycling: "Skip when cycling",
        audioPrioritySetOutput: "Set as audio output",
        audioPrioritySetInput: "Set as audio input",

        updatesSection: "Updates",
        betaBadgeLabel: "Beta",
        updateChecking: "Checking…",
        updateUpToDate: "You’re on the latest version.",
        updateAvailablePrefix: "Update available:",
        updateInstallButton: "Download and install",
        updateDownloading: "Downloading update…",
        updateInstalling: "Installing and restarting…",
        updateFailedPrefix: "Couldn’t check:",
        updateLastChecked: "Last checked:",
        updateNotifyTitle: "Lattice update",
        updateInstallFailedBody: "The update was downloaded but could not be applied. Download the latest version from the GitHub releases page and drag the app over the current one.",
        updateNeedsApplicationsTitle: "Move Lattice to Applications",
        updateNeedsApplicationsBody: "The app is running from a place that cannot be updated, such as the disk image or a temporary system location. Drag Lattice to the Applications folder, open it from there and try again.",

        permissionRequired: "Permission required",
        permissionAccessibility: "Device Control and Data Access",
        permissionScreenRecording: "Screen Recording",
        permissionGranted: "Granted",
        permissionMissing: "Not granted",
        permissionOpenSettings: "Open System Settings…",
        permissionRequest: "Grant access",
        permissionRestartNote: "macOS may ask to reopen the app after granting.",
        secureInputTitle: "Secure input is on",
        secureInputHeldFormat: "%@ is holding it, so Lattice cannot type for you. Dismiss its password field, or quit it, to release it.",
        secureInputUnattributed: "No running app claims it. Log out and back in to clear it.",
        secureInputUnidentified: "The app holding it could not be identified, so Lattice cannot type for you.",
        secureInputRevealFormat: "Show %@",

        aboutDescription: "A utility hub for your Mac.\nEnergy, system monitor, scrolling and a window switcher, right in the menu bar.",
        versionPrefix: "Version",
        navigationBack: "Back",
        releaseNotesFallback: "This update includes the latest fixes and improvements.",

        tabMonitor: "System Monitor",
        monitorSeparateMenuBarMetrics: "Show readings separately",
        monitorSeparateMenuBarMetricsCaption: "Separates active blocks in the menu bar and keeps usage and temperature together when combine is on.",
        monitorNetworkUploadFirst: "Upload above download",
        monitorShowCPU: "CPU",
        monitorShowMemory: "Memory",
        monitorShowNetwork: "Network",
        monitorShowPowerLabel: "Power",
        betaBadge: "BETA",
        betaFeatureWarning: "Beta. You may run into some bugs.",

        networkSection: "Network",
        networkApps: "Apps using network",
        networkAppsIdle: "No apps using network now",

        diskSection: "Disks",
        diskMenuBarStyleLabel: "Disk display",
        diskMenuBarUsedPercentage: "Used percentage",
        diskMenuBarAvailableSpace: "Available space",
        diskMenuBarUsedSpace: "Used space",
        diskAvailable: "available",
        diskPurgeable: "purgeable",
        diskStorageSettings: "Storage",
        diskNoDisks: "No mounted disks found.",

        powerSection: "Power",
        powerCharging: "Charging",
        powerOnBattery: "On battery",
        powerPluggedIn: "Plugged in",
        powerUnavailable: "Power metrics unavailable on this Mac",
        powerAdapterMaxFormat: "%@ max",
        monitorShowGPU: "GPU",
        monitorShowCPUTemperature: "CPU temperature",
        monitorShowGPUTemperature: "GPU temperature",
        monitorShowBatteryTemperature: "Battery temperature",
        monitorShowPeripheralBattery: SettingsFollowupStrings.text(.accessoryBattery, .enUS),

        updateBannerTitle: "Update available",
        menuBarSpacingLabel: "Menu bar spacing",
        menuBarSpacingStandard: "Standard",
        menuBarSpacingCompact: "Compact",
        monitorMemoryPressureDot: "Pressure dot",
        systemUptime: "Up for",
        powerCycles: "Cycles",
        speedTestRun: "Speed test",

        disclosureExpanded: "Expanded",
        disclosureCollapsed: "Collapsed",
        panelHiddenItem: "Hidden",
        monitorItemDiskUsage: "Disk usage",
        monitorItemDiskActivity: "Live activity",

        cleaningMenuItem: "Cleaning Mode",
        windowMaximizeName: "Maximize Windows",
        windowMaximizeCaption: "Use macOS window controls to maximize the window without moving it to a separate full-screen Space.",
        keyDebounceName: "Duplicate Key Protection",
        keyDebounceEnable: "Ignore double typing",
        keyDebounceCaption: "Ignore accidental key repeats from a single press.",
        keyDebounceGlobalWindow: "Repeat filter interval",
        keyDebouncePerKeySection: "Customize by key",
        keyDebouncePerKeyCaption: "Per-key values override the global window. Use 0 ms to stop filtering a key.",
        keyDebounceKeyLabel: "Key",
        keyDebounceAddKey: "Add key",
        keyDebounceRemoveKey: "Remove",
        cleaningPanelCaption: "Locks the keyboard so you can clean safely.",
        cleaningOverlayTitle: "Keyboard locked for cleaning",
        cleaningOverlaySubtitle: "Press Escape 5 times to unlock",
        cleaningOverlayUnlock: "Unlock",
        cleaningOverlayMouseHint: "Your mouse and trackpad still work",
        cleaningNeedsAxTitle: "Accessibility needed",
        cleaningNeedsAxBody: "To lock the keyboard safely, Lattice needs Accessibility permission. Grant it in System Settings and try again.",
        shortcutsPageTitle: "Keyboard Shortcuts",
        settingsSearchPlaceholder: "Search settings",
        doneButton: "Done",
        homebrewOfficialIntroTitle: "Now in the official Homebrew catalog",
        homebrewOfficialIntroMessage: "Lattice can now be installed directly from the official Homebrew catalog.",
        homebrewOfficialIntroInstallLabel: "New installation",
        homebrewOfficialIntroMigrationTitle: "Used the old tap?",
        homebrewOfficialIntroMigrationMessage: "Remove the tap once. The app and your settings stay in place.",
        homebrewOfficialIntroCopyButton: "Copy command",
        shortcutRecording: "Press the new shortcut",
        shortcutReset: "Reset",
        shortcutNone: "None",
        shortcutClear: "Remove shortcut",
        shortcutInvalid: "Use at least Control, Option or Command with a key.",
        shortcutPressKeys: "Press keys",
        shortcutEscapeHint: "Escape cancels.",
        shortcutDeleteHint: "Delete clears.",
        shortcutConflictFormat: "This shortcut is already used by %@.",
        shortcutTakeOverOffer: "macOS uses %@ for one of its own shortcuts.",
        shortcutTakeOverAction: "Take over while Lattice runs",
        shortcutTakeOverCaption: "macOS gets the key back whenever Lattice is not running or this feature is off.",
        shortcutTakeOverDismiss: "Don’t take over",
        shortcutUnavailable: "macOS rejected this shortcut. Choose another one.",
        musicBlockSection: "Disable media key",
        musicBlockTitle: "Stop Music from opening on its own",
        musicBlockCaption: "Stop using the media key to start up the default music app",
        musicBlockUnavailable: "This protection is unavailable right now. Turn it off and on to try again.",
        musicBlockPlayReplacement: "Play after opening replacement",
        cleanerName: "Cleaner",
        cleanerIntroTitle: "Clean up your Mac",
        cleanerIntroCaption: "Scans for leftovers from uninstalled apps, caches, logs and the Trash. You review everything first and removed items go to the Trash.",
        cleanerScan: "Scan",
        cleanerScanning: "Scanning…",
        cleanerCleaning: "Cleaning…",
        cleanerCatLeftovers: "Leftovers from uninstalled apps",
        cleanerCatLoginItems: "Orphaned startup items",
        cleanerCatCaches: "Caches",
        cleanerCatLogs: "Logs",
        cleanerCatDeveloper: "Developer junk",
        cleanerCatTrash: "Trash",
        cleanerLeftoversNote: "Found by analysis and left unchecked. Check the path before ticking.",
        cleanerLoginItemsNote: "The entry under Login Items disappears after restarting the Mac.",
        cleanerTrashNote: "Emptying the Trash is permanent.",
        cleanerCatDeviceBackups: "iPhone backups",
        cleanerDeviceBackupsCaption: "Old iPhone and iPad backups take a big slice of the storage macOS calls Other. Remove only the ones you no longer need; a new backup is made when you plug the device in again.",
        cleanerCatScreenshots: "Forgotten screenshots",
        cleanerScreenshotsCaptionFormat: "Screenshots you have not opened in %d days that still have the name and folder macOS gave them. Ones you renamed or moved never show up here.",
        cleanerScreenshotsSettingCaption: "The scan lists the screenshots you have not opened for this long, unchecked, with their total size.",
        cleanerScreenshotsAfterFormat: "After %d days",
        cleanerNothingFound: "Nothing to clean. Your Mac is tidy.",
        cleanerDoneNote: "Items went to the Trash and can be recovered from there.",
        cleanerAgain: "Scan again",
        cleanerRevealInFinder: "Reveal in Finder",
        cleanerSafeSection: "Safe cleanup",
        cleanerOptionalSection: "Optional, review first",
        cleanerCatOtherCaches: "Other caches",
        cleanerCachesCaption: "Temporary files apps rebuild on their own.",
        cleanerLogsCaption: "Old diagnostic logs.",
        cleanerDeveloperCaption: "Xcode build and simulator leftovers.",
        cleanerLoginItemsCaption: "Startup entries left by apps that no longer exist.",
        cleanerLeftoversCaption: "Files left behind by apps you uninstalled.",
        cleanerOtherCachesCaption: "Safe to remove, nothing breaks. Apps may open slower once and downloaded content, like offline music, downloads again.",
        cleanerCleanSizeFormat: "Clean %@",
        cleanerScheduleTitle: "Automatic cleanup",
        cleanerScheduleOff: "Off",
        cleanerScheduleDaily: "Daily",
        cleanerScheduleWeekly: "Weekly",
        cleanerScheduleCaption: "Cleans only the safe part on its own at the chosen time and sends everything to the Trash.",
        cleanerScheduleLastFormat: "The last automatic cleanup freed %@.",
        cleanerAutoNotificationFormat: "%@ freed and sent to the Trash.",
        cleanerScheduleNextFormat: "Next cleanup %@.",
        cleanerScheduleRanFormat: "Last automatic cleanup %@.",
        cleanerScheduleNotifyToggle: "Notify when done",
        cleanerNotifDenied: "Lattice notifications are turned off in the system.",
        cleanerNotifOpenSettings: "Open Notification Settings…",
        launchAtLoginNeedsApplications: "The app is running from a place that cannot open at login. Drag Lattice to the Applications folder, open it from there and turn this on again.",
        launchAtLoginNeedsApproval: "The login item is registered, but macOS still needs your approval. In System Settings, allow Lattice to open at login and to run in the background.",
        ocrRemoveLineBreaksToggle: "Remove line breaks",
        ocrRemoveLineBreaksCaption: "Removes line breaks so copied text pastes as one paragraph.",
        ocrQRToggle: "Read QR codes",
        ocrQRCaption: "If the area has a QR code, its content is shown to copy or open.",
        ocrQRCopied: "QR code copied",
        qrResultTitle: "QR code",
        qrResultCopy: "Copy",
        qrResultOpen: "Open link",
        switcherCurrentSpaceOnly: "Only show windows from current desktop",
        switcherCurrentSpaceOnlyCaption: "Lists windows from the current desktop. Fullscreen windows from other desktops also appear while “Show fullscreen windows” is on.",
        shelfFileMissing: "The file no longer exists",
        previewSizeSmall: "Small",
        mixerSoundEffectsOutputTitle: "System sounds",
        mixerSoundEffectsOutputTooltip: "Choose where alerts and sound effects play",
        monitorOpenActivityMonitor: "Open Activity Monitor",
        dockClickHide: "Click the dock tile to hide the app",
        dockClickHideCaption: "The active app hides when you click its dock tile. Click again to bring it back.",
        urlCleanerRemovedFormat: "Removed %@",
        switcherSearchPlaceholder: "Search",
        invertVerticalScroll: "Invert vertical scrolling",
        invertHorizontalScroll: "Invert horizontal scrolling",
        scrollHorizontalName: "Scroll sideways while holding a key",
        scrollHorizontalModifierLabel: "Modifier key",
        scrollHorizontalCommandKey: "Command",
        scrollHorizontalCaption: "Hold the selected key while using the mouse wheel to scroll sideways.",
        switcherShowShortcutHints: "Show shortcut hints",
        switcherShowShortcutHintsCaption: "Shows the app and window shortcuts below the icons.",
        uninstallerHomebrewPackageFormat: "%@ will also be removed from Homebrew.",
        uninstallerHomebrewCheckFailed: "Could not verify whether Homebrew manages this app. Refresh to try again, or uninstall it from Homebrew.",
        shelfEdgeToggle: "Open near a screen edge",
        shelfEdgeCaption: "Drag a file toward the screen edge to peek the File Cache in. Drop it there, or pull back and it retreats.",
        focusFollowsMouseName: "Focus follows mouse",
        focusFollowsMouseCaption: "Focuses the window under the pointer.",
        focusFollowsMouseDelay: "Hover delay",
        focusFollowsMouseRaise: "Bring the window to the front",
        focusFollowsMouseWaitForStop: "Wait for the pointer to stop",
        switcherMinimizedPlacementLabel: "Show minimized windows",
        switcherMinimizedPlacementNormal: "In recent order",
        switcherMinimizedPlacementEnd: "After other windows",
        switcherMinimizedPlacementHidden: "Never",
        switcherShowFullscreenWindows: "Show fullscreen windows",
        switcherScreenPlacementLabel: "Show switcher on",
        switcherScreenPlacementPointer: "Screen containing mouse",
        switcherScreenPlacementMenuBar: "Primary screen",
        switcherScreenPlacementActiveWindow: "Screen with active window",
        switcherCurrentDisplayOnly: "Only show windows from current display",
        switcherCurrentDisplayOnlyCaption: "Lists only windows on the display under the pointer. If that display has no windows, the switcher does not open.",
        smoothScrollResponseLabel: "Response",
        smoothScrollCoastLabel: "Coast",
        mouseAccelerationName: "Disable pointer acceleration",
        mouseAccelerationCaption: "Pointer travel follows hand distance, not speed.",
        linearScrollName: "Linear scrolling",
        linearScrollCaption: "Scroll the same distance with each wheel step, regardless of speed.",
        linearScrollLinesLabel: "Lines per step",
        scrollSpeedName: "Scroll faster while holding a key",
        scrollSpeedCaption: "Hold the selected key while using the mouse wheel to scroll faster.",
        scrollSpeedMultiplierLabel: "Speed",
        shelfClearOnClose: "Clear when closed",
        shelfClearOnCloseCaption: "Empties the File Cache only when you click its close button. Automatic hiding and collapsing keep the items.",
        shelfShortcutFinderSelection: "Add the Finder selection with the shortcut",
        shelfShortcutFinderSelectionCaption: "With Finder in front, the shortcut opens the File Cache with the selected files already in it. With nothing selected, it opens as usual.",
        spacesOrderName: "Disable Space Reorder",
        spacesOrderCaption: "Keeps Spaces in your chosen order instead of rearranging them by recent use."
    )
}

extension Strings {
    var tabAdvanced: String { "Advanced" }
    var uninstallerRefusedNotApp: String { "Only apps can be uninstalled." }
    var uninstallerRefusedSystemFormat: String { "%@ can’t be uninstalled because it’s part of macOS." }
    var uninstallerRefusedSharedFormat: String { "%@ can’t be uninstalled here because it shares files with macOS or other apps." }
    var uninstallerRefusedNestedFormat: String { "%@ can’t be uninstalled on its own because it’s part of another app." }
    var uninstallerRefusedSelfFormat: String { "Lattice can’t uninstall itself here. Use Settings › %@ instead." }
    var uninstallerRefusedLinkFormat: String { "%@ can’t be uninstalled because it’s a link to an app stored elsewhere." }
    var uninstallerRefusedUnidentifiedFormat: String { "%@ can’t be uninstalled because it can’t be identified as an app." }
    var uninstallerPickerHiddenNote: String { "Apps that are part of macOS or made by Apple aren’t listed." }


    var secureInputSwitcherHeldFormat: String {
        switch L10n.shared.language {
        case .ptBR: return "%@ era o app em primeiro plano quando ela foi ligada e pode estar mantendo-a ativa. Até ela ser desativada, o macOS esconde do alternador as teclas que você pressiona e o ⌘Tab abre o alternador do macOS. Saia do campo de senha do app, ou encerre-o, para liberá-la."
        case .zhHans: return "它开启时 %@ 位于前台，可能正在占用它。在安全输入关闭前，macOS 会对切换器隐藏你的按键，⌘Tab 会改为打开 macOS 的切换器。退出其密码栏或退出该 App 即可释放。"
        case .zhHK, .zhTW: return "它開啟時 %@ 位於前景，可能正在佔用它。在安全輸入關閉前，macOS 會對切換器隱藏你的按鍵，⌘Tab 會改為開啟 macOS 的切換器。離開其密碼欄位或結束該 App 即可釋放。"
        case .fr: return "%@ était l’app au premier plan quand elle s’est activée et la maintient peut-être. Tant que la saisie sécurisée reste activée, macOS cache au sélecteur les touches que vous tapez et ⌘Tab ouvre le sélecteur de macOS à la place. Quittez son champ de mot de passe, ou fermez l’app, pour la libérer."
        case .de: return "%@ war die aktive App, als sie eingeschaltet wurde, und hält sie möglicherweise. Solange die sichere Eingabe aktiv ist, verbirgt macOS deine Tastenanschläge vor dem Umschalter und ⌘Tab öffnet stattdessen den macOS-Umschalter. Verlasse das Passwortfeld oder beende die App, um sie freizugeben."
        case .it: return "%@ era l’app in primo piano quando si è attivato e potrebbe trattenerlo. Finché resta attivo, macOS nasconde al commutatore i tasti che premi e ⌘Tab apre invece il commutatore di macOS. Esci dal suo campo password, o chiudi l’app, per rilasciarlo."
        case .ja: return "オンになったときに最前面にあったのは %@ で、このアプリが保持している可能性があります。セキュア入力がオンの間は、macOS がスイッチャーからキー入力を隠し、⌘Tab では代わりに macOS のスイッチャーが開きます。パスワード欄からフォーカスを外すか、アプリを終了すると解除されます。"
        case .ko: return "보안 입력이 켜질 때 %@이(가) 활성 앱이었으며, 이 앱이 보안 입력을 유지하고 있을 수 있습니다. 보안 입력이 켜져 있는 동안 macOS가 전환기에서 키 입력을 숨기고, ⌘Tab을 누르면 대신 macOS 전환기가 열립니다. 암호 필드에서 포커스를 옮기거나 앱을 종료하면 해제됩니다."
        case .ru: return "Когда он включился, активным приложением было %@, и, возможно, именно оно его удерживает. Пока он включён, macOS скрывает нажатия клавиш от переключателя и ⌘Tab вместо него открывает переключатель macOS. Снимите фокус с поля пароля или завершите работу приложения, чтобы освободить его."
        case .sk: return "Keď sa zapol, aktívnou aplikáciou bola %@ a možno ho drží. Kým je zapnutý, macOS skrýva stlačené klávesy pred prepínačom a ⌘Tab namiesto neho otvára prepínač macOS. Zavrite jej pole s heslom alebo ju ukončite, aby ho uvoľnila."
        case .es: return "%@ era la app en primer plano cuando se activó y puede que la esté reteniendo. Mientras la entrada segura siga activada, macOS oculta al selector las teclas que pulsas y ⌘Tab abre el selector de macOS en su lugar. Sal de su campo de contraseña, o ciérrala, para liberarla."
        case .tr: return "Açıldığında etkin uygulama %@ idi ve bunu o açık tutuyor olabilir. Güvenli giriş açık kaldıkça macOS bastığın tuşları değiştiriciden gizliyor ve ⌘Tab onun yerine macOS değiştiricisini açıyor. Serbest bırakmak için parola alanından çık ya da uygulamayı kapat."
        case .uk: return "Коли його було увімкнено, активною програмою була %@, і, можливо, саме вона його утримує. Поки воно увімкнене, macOS приховує натискання клавіш від перемикача і ⌘Tab натомість відкриває перемикач macOS. Приберіть поле пароля програми або завершіть її, щоб звільнити."
        case .enUS: return "%@ was the active app when it turned on and may be holding it. Until it turns off, macOS hides your keystrokes from the switcher and ⌘Tab opens the macOS switcher instead. Dismiss its password field, or quit it, to release it."
        }
    }

    var secureInputSwitcherUnattributed: String {
        switch L10n.shared.language {
        case .ptBR: return "Não é possível dizer qual app a está mantendo ativa. Até ela ser desativada, o macOS esconde do alternador as teclas que você pressiona e o ⌘Tab abre o alternador do macOS. Saia de qualquer campo de senha aberto, ou encerre a sessão e entre novamente, para limpá-la."
        case .zhHans: return "无法确定占用它的 App。在安全输入关闭前，macOS 会对切换器隐藏你的按键，⌘Tab 会改为打开 macOS 的切换器。退出已打开的密码栏，或注销后重新登录即可清除。"
        case .zhHK, .zhTW: return "無法確定佔用它的 App。在安全輸入關閉前，macOS 會對切換器隱藏你的按鍵，⌘Tab 會改為開啟 macOS 的切換器。離開已開啟的密碼欄位，或登出後重新登入即可清除。"
        case .fr: return "Impossible de savoir quelle app la maintient. Tant que la saisie sécurisée reste activée, macOS cache au sélecteur les touches que vous tapez et ⌘Tab ouvre le sélecteur de macOS à la place. Quittez tout champ de mot de passe ouvert, ou déconnectez-vous puis reconnectez-vous, pour l’effacer."
        case .de: return "Die App, die sie hält, lässt sich nicht bestimmen. Solange die sichere Eingabe aktiv ist, verbirgt macOS deine Tastenanschläge vor dem Umschalter und ⌘Tab öffnet stattdessen den macOS-Umschalter. Verlasse ein offenes Passwortfeld oder melde dich ab und wieder an, um sie zurückzusetzen."
        case .it: return "Non è possibile sapere quale app lo stia trattenendo. Finché resta attivo, macOS nasconde al commutatore i tasti che premi e ⌘Tab apre invece il commutatore di macOS. Chiudi qualsiasi campo password aperto, oppure esci e accedi di nuovo, per azzerarlo."
        case .ja: return "保持しているアプリを特定できません。セキュア入力がオンの間は、macOS がスイッチャーからキー入力を隠し、⌘Tab では代わりに macOS のスイッチャーが開きます。開いているパスワード欄からフォーカスを外すか、ログアウトしてから再度ログインすると解除されます。"
        case .ko: return "보안 입력을 유지하는 앱을 알 수 없습니다. 보안 입력이 켜져 있는 동안 macOS가 전환기에서 키 입력을 숨기고, ⌘Tab을 누르면 대신 macOS 전환기가 열립니다. 열려 있는 암호 필드에서 포커스를 옮기거나 로그아웃한 후 다시 로그인하면 해제됩니다."
        case .ru: return "Не удаётся определить, какое приложение его удерживает. Пока он включён, macOS скрывает нажатия клавиш от переключателя и ⌘Tab вместо него открывает переключатель macOS. Снимите фокус с открытого поля пароля или выйдите из системы и войдите снова, чтобы сбросить его."
        case .sk: return "Nedá sa určiť, ktorá aplikácia ho drží. Kým je zapnutý, macOS skrýva stlačené klávesy pred prepínačom a ⌘Tab namiesto neho otvára prepínač macOS. Zavrite otvorené pole s heslom alebo sa odhláste a znova prihláste, aby sa uvoľnil."
        case .es: return "No se puede saber qué app la está reteniendo. Mientras la entrada segura siga activada, macOS oculta al selector las teclas que pulsas y ⌘Tab abre el selector de macOS en su lugar. Sal de cualquier campo de contraseña abierto, o cierra la sesión y vuelve a iniciarla, para borrarla."
        case .tr: return "Bunu açık tutan uygulama belirlenemiyor. Güvenli giriş açık kaldıkça macOS bastığın tuşları değiştiriciden gizliyor ve ⌘Tab onun yerine macOS değiştiricisini açıyor. Temizlemek için açık bir parola alanı varsa ondan çık ya da oturumu kapatıp yeniden aç."
        case .uk: return "Не вдається визначити, яка програма його утримує. Поки воно увімкнене, macOS приховує натискання клавіш від перемикача і ⌘Tab натомість відкриває перемикач macOS. Приберіть відкрите поле пароля або вийдіть із сеансу та увійдіть знову, щоб скинути."
        case .enUS: return "The app holding it cannot be named. Until it turns off, macOS hides your keystrokes from the switcher and ⌘Tab opens the macOS switcher instead. Dismiss any open password field, or log out and back in, to clear it."
        }
    }

    var secureInputSwitcherUnidentified: String {
        switch L10n.shared.language {
        case .ptBR: return "Não foi possível identificar o app que a está mantendo ativa. Até ela ser desativada, o macOS esconde do alternador as teclas que você pressiona e o ⌘Tab abre o alternador do macOS."
        case .zhHans: return "无法识别占用它的 App。在安全输入关闭前，macOS 会对切换器隐藏你的按键，⌘Tab 会改为打开 macOS 的切换器。"
        case .zhHK, .zhTW: return "無法辨識佔用它的 App。在安全輸入關閉前，macOS 會對切換器隱藏你的按鍵，⌘Tab 會改為開啟 macOS 的切換器。"
        case .fr: return "L’app qui la maintient n’a pas pu être identifiée. Tant que la saisie sécurisée reste activée, macOS cache au sélecteur les touches que vous tapez et ⌘Tab ouvre le sélecteur de macOS à la place."
        case .de: return "Die App, die sie hält, konnte nicht identifiziert werden. Solange die sichere Eingabe aktiv ist, verbirgt macOS deine Tastenanschläge vor dem Umschalter und ⌘Tab öffnet stattdessen den macOS-Umschalter."
        case .it: return "Non è stato possibile identificare l’app che lo sta trattenendo. Finché resta attivo, macOS nasconde al commutatore i tasti che premi e ⌘Tab apre invece il commutatore di macOS."
        case .ja: return "保持しているアプリを特定できません。セキュア入力がオンの間は、macOS がスイッチャーからキー入力を隠し、⌘Tab では代わりに macOS のスイッチャーが開きます。"
        case .ko: return "보안 입력을 유지하는 앱을 확인할 수 없습니다. 보안 입력이 켜져 있는 동안 macOS가 전환기에서 키 입력을 숨기고, ⌘Tab을 누르면 대신 macOS 전환기가 열립니다."
        case .ru: return "Не удалось определить приложение, которое его удерживает. Пока он включён, macOS скрывает нажатия клавиш от переключателя и ⌘Tab вместо него открывает переключатель macOS."
        case .sk: return "Aplikáciu, ktorá ho drží, sa nepodarilo identifikovať. Kým je zapnutý, macOS skrýva stlačené klávesy pred prepínačom a ⌘Tab namiesto neho otvára prepínač macOS."
        case .es: return "No se ha podido identificar la app que la está reteniendo. Mientras la entrada segura siga activada, macOS oculta al selector las teclas que pulsas y ⌘Tab abre el selector de macOS en su lugar."
        case .tr: return "Bunu açık tutan uygulama belirlenemedi. Güvenli giriş açık kaldıkça macOS bastığın tuşları değiştiriciden gizliyor ve ⌘Tab onun yerine macOS değiştiricisini açıyor."
        case .uk: return "Програму, що утримує його, не вдалося розпізнати. Поки воно увімкнене, macOS приховує натискання клавіш від перемикача і ⌘Tab натомість відкриває перемикач macOS."
        case .enUS: return "The app holding it could not be identified. Until it turns off, macOS hides your keystrokes from the switcher and ⌘Tab opens the macOS switcher instead."
        }
    }
}

