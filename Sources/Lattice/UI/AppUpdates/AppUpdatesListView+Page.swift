// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var overhauledBody: some View {
        AppManagerPage {
            statusCard

            updatesSection

            // After the list so it never pushes actionable updates down as a check finishes.
            if coverageIncomplete {
                pageIncompleteNote
                    .transition(reduceMotion ? .identity : .settingsReveal)
            }

            updateSourcesSection

            preferencesSection
        } footer: {
            if let status = appUpdatesOperationStatus {
                AppManagerDockedFooter(progress: status.isActive ? status.progressFraction : nil) {
                    HomebrewCompactOperationFooter(status: status)
                }
            }
        }
        .settingsExpansionAnimation(value: updates.isChecking)
        .settingsExpansionAnimation(value: updates.isChecking ? [] : updates.items.map(\.id))
        .settingsExpansionAnimation(value: coverageIncomplete)
        .settingsExpansionAnimation(value: showsNotifyRow)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: appUpdatesOperationStatus?.targetID)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: appUpdatesOperationStatus?.result)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: homebrew.isOperationDetailsExpanded)
        .sheet(isPresented: $showingALS) {
            alsSheet
        }
        .onChange(of: statusHeadline) { _, newHeadline in
            AccessibilityNotification.Announcement("\(newHeadline), \(statusDetail)").post()
        }
        .onChange(of: homebrew.operationStatus?.targetID) { _, _ in
            homebrew.setOperationDetailsExpanded(false)
        }
    }

    /// Top status card matching Homebrew's top card: headline and last-checked
    /// summary on the left, Check Now / Retry pill on the right.
    @ViewBuilder
    private var statusCard: some View {
        if updates.isChecking && !updates.hasCheckedThisSession {
            statusSkeleton
                .transition(reduceMotion ? .identity : .opacity)
        } else {
            let hasError = updates.lastError?.isEmpty == false
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(updates.isChecking ? text.checking + "…" : statusHeadline)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(updates.isChecking ? text.checking + "…" : statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if !allSourcesOff && AppFeature.appUpdates.isAvailable {
                    Button(updates.isChecking ? text.checking + "…" : (hasError ? text.retry : text.checkNow)) {
                        updates.check()
                    }
                    .buttonStyle(.appManager(hasError && !updates.isChecking ? .accent : .neutral))
                    .disabled(isBusy)
                    .fixedSize()
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .transition(reduceMotion ? .identity : .opacity)
        }
    }

    private var statusSkeleton: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 3).frame(width: 170, height: 12)
                RoundedRectangle(cornerRadius: 3).frame(width: 120, height: 9)
            }
            Spacer(minLength: 8)
            Capsule().frame(width: 86, height: 26)
        }
        .foregroundStyle(Color.primary.opacity(0.08))
        .padding(.vertical, 3)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Which apps the check left out, using the shared App Manager banner.
    var pageIncompleteNote: some View {
        AppManagerBanner(title: text.incompleteCheck, detail: incompleteCheckDetail) {
            EmptyView()
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppManagerSectionHeader(
                title: text.pageTitle,
                meta: (updates.isChecking || updates.items.isEmpty) ? nil : "\(updates.items.count)"
            )
            SettingsCard {
                pageResults
            }
        }
    }

    @ViewBuilder
    var pageResults: some View {
        if allSourcesOff {
            noSourcesCard
                .transition(reduceMotion ? .identity : .opacity)
        } else if updates.isChecking {
            AppManagerListSkeleton(rows: 3)
                .transition(reduceMotion ? .identity : .opacity)
                .accessibilityLabel(text.checking)
        } else if !updates.items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(updates.items.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: 0) {
                        if index > 0 {
                            Divider()
                                .padding(.leading, 42)
                                .padding(.vertical, 6)
                        }
                        row(item)
                    }
                    .transition(reduceMotion ? .identity : .settingsReveal)
                }
            }
            .transition(reduceMotion ? .identity : .opacity)
        } else {
            if let error = updates.lastError, !error.isEmpty {
                errorCard
                    .transition(reduceMotion ? .identity : .opacity)
            } else {
                caughtUpCard
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
    }
}
