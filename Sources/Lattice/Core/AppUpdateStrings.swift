// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct AppUpdateStrings {
    let pageTitle: String
    let hubDescription: String
    let caption: String
    let panelCaption: String
    let checkNow: String
    let checking: String
    let lastCheckFormat: String
    let neverChecked: String
    let upToDate: String
    let partialUpToDate: String
    let coverageNote: String
    let selectAll: String
    let clearSelection: String
    let updateSelectedFormat: String
    let updateOne: String
    let openAppStore: String
    let appStoreBadge: String
    let storeHint: String
    let frequencyLabel: String
    let frequencyOff: String
    let frequencyDaily: String
    let frequencyWeekly: String
    let nextCheckFormat: String
    let notifyToggle: String
    let includeStoreToggle: String
    let includeStoreCaption: String
    let packageMissing: String
    let notificationBodyFormat: String
    /// Used when exactly one app is waiting, so the note never reads "1 apps".
    let notificationBodyOne: String
    let showInPanel: String
    let homebrewBadge: String
    let sourcesTitle: String
    let includeHomebrewToggle: String
    let onlineBadge: String
    let openApp: String
    let openAppHint: String
    let includeOnlineToggle: String
    let includeOnlineCaption: String
    let incompleteCheck: String
    let onlineUnavailable: String
    let skipVersionFormat: String
    let excludeApp: String
    let rulesTitle: String
    let addException: String
    let skippedVersionFormat: String
    let excludedApp: String
    let removeRule: String
    let rulesHint: String
    let noVisibleUpdates: String
    let uncomparableVersions: String
    let uncomparableVersionsNote: String
    let noSourcesSelected: String
    let checksOff: String
    let checksOffDetail: String
    let foundCountFormat: String
    let availableCountFormat: String
    let checkFailed: String
    let retryHint: String
    let checkedRelativeFormat: String
    let availableUpdatesTitle: String
    let appCountFormat: String
    let updatePreferences: String
    let applicationChannel: String
    let applicationChannelCaption: String
    let excludedAppsTitle: String
    let excludedCountFormat: String
    let manage: String
    let manageExcludedApps: String
    let noExcludedApps: String
    let excludedAppsCaption: String
    let noExcludedAppsDetail: String
    let selectSource: String
    let selectSourceDetail: String
    let justNow: String
    let updating: String
    let openToUpdate: String
    let updateAppFormat: String
    let openToUpdateAppFormat: String
    let retry: String
    let checkedAppsFormat: String
}
extension FeatureStrings {
    static func appUpdates(_ language: AppLanguage) -> AppUpdateStrings {
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
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}
