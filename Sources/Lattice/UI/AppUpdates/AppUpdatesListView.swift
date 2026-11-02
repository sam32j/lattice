// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The app update list, shared by the Settings page and the menu bar panel so
/// both look and behave cleanly. `compact` shrinks it for the panel.
struct AppUpdatesListView: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var updates = AppUpdatesService.shared
    @ObservedObject var homebrew = HomebrewManager.shared
    @Environment(\.notchPresentation) var inNotch
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage(DefaultsKey.appUpdatesCheckFrequency)
    var frequencyRaw = AppUpdatesSupport.CheckFrequency.off.rawValue
    @AppStorage(DefaultsKey.appUpdatesNotify) var notify = true
    @AppStorage(DefaultsKey.appUpdatesIncludeHomebrewApps) var includeHomebrewApps = true
    @AppStorage(DefaultsKey.appUpdatesIncludeAppStore)
    var includeAppStore = true
    @AppStorage(DefaultsKey.appUpdatesIncludeOnlineCatalog)
    var includeOnlineCatalog = true
    @State var showingALS = false
    @State var showingAppPicker = false
    @State var showOperationDetails = false
    @State var skeletonPulse = false
    var compact = false

    var currentFrequency: AppUpdatesSupport.CheckFrequency {
        AppUpdatesSupport.CheckFrequency.sanitized(frequencyRaw)
    }

    var isScheduleOff: Bool {
        currentFrequency == .off
    }

    var allSourcesOff: Bool {
        !includeHomebrewApps && !includeAppStore && !includeOnlineCatalog
    }

    var isScheduleControlDisabled: Bool {
        allSourcesOff
    }

    var isNotifyControlDisabled: Bool {
        isScheduleOff || allSourcesOff
    }

    var excludedRules: [AppUpdatesSupport.UpdateRule] {
        updates.rules.filter { $0.version == nil }
    }

    var excludedCount: Int {
        excludedRules.count
    }

    var excludedSummaryText: String {
        String(format: text.excludedCountFormat, excludedCount)
    }

    var notifyDisplayBinding: Binding<Bool> {
        Binding {
            isNotifyControlDisabled ? false : notify
        } set: { newValue in
            guard !isNotifyControlDisabled else { return }
            notify = newValue
            if newValue {
                Notifier.requestPermission()
            }
        }
    }

    var text: AppUpdateStrings { FeatureStrings.appUpdates(l10n.language) }
    /// The row menu holds both rule actions, so it is named for neither.
    var moreOptions: String { FeatureStrings.mouseClickDebounce(l10n.language).moreOptions }
    var isBusy: Bool { updates.isChecking || homebrew.operation != nil }
    var storeCoverageIncomplete: Bool {
        includeAppStore && !updates.appStoreAvailable
    }
    var coverageIncomplete: Bool {
        updates.hasCheckedThisSession
            && !updates.isChecking
            && (storeCoverageIncomplete || (includeOnlineCatalog && !updates.onlineCatalogAvailable))
    }
    var versionsUncompared: Bool {
        updates.hasCheckedThisSession
            && !updates.isChecking
            && includeOnlineCatalog && !updates.uncomparableAppNames.isEmpty
    }
    /// An app named as not compared is not known to be current either.
    var coveragePartial: Bool { coverageIncomplete || versionsUncompared }

    var totalAppsCount: Int {
        allSourcesOff ? 0 : updates.totalAppsCount
    }

    var successfulEmptyCheck: Bool {
        AppFeature.appUpdates.isAvailable && !allSourcesOff && updates.hasCheckedThisSession
            && !updates.isChecking && updates.items.isEmpty
            && updates.lastError?.isEmpty != false && !coveragePartial
    }

    var statusHeadline: String {
        if allSourcesOff { return text.noSourcesSelected }
        if !AppFeature.appUpdates.isAvailable { return text.checksOff }
        if updates.isChecking {
            return updates.items.isEmpty ? text.checking : String(format: text.foundCountFormat, updates.items.count)
        }
        if let error = updates.lastError, !error.isEmpty { return text.checkFailed }
        guard updates.hasCheckedThisSession else { return text.neverChecked }
        if !updates.items.isEmpty { return String(format: text.availableCountFormat, updates.items.count) }
        return coveragePartial ? text.partialUpToDate : text.upToDate
    }

    var statusDetail: String {
        if allSourcesOff { return text.selectSourceDetail }
        if !AppFeature.appUpdates.isAvailable { return text.checksOffDetail }
        if updates.isChecking { return text.checking }
        if let error = updates.lastError, !error.isEmpty { return text.retryHint }
        guard updates.hasCheckedThisSession else { return text.neverChecked }
        let checked = String(format: text.checkedRelativeFormat, lastCheckRelativeText)
        guard totalAppsCount > 0 else { return checked }
        return checked + " · " + String(format: text.appCountFormat, totalAppsCount)
    }

    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter
    }()

    var lastCheckRelativeText: String {
        guard let last = updates.lastCheck else { return text.justNow }
        if Date().timeIntervalSince(last) < 60 { return text.justNow }
        Self.relativeDateFormatter.locale = l10n.language.formattingLocale()
        return Self.relativeDateFormatter.localizedString(for: last, relativeTo: Date())
    }

    var body: some View {
        if compact {
            compactBody
        } else {
            overhauledBody
        }
    }

    // MARK: - Overhauled Page Layout

}
