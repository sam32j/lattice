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
        let hasError = updates.lastError?.isEmpty == false
        HStack(spacing: 12) {
            if updates.isChecking {
                statusTitleSkeleton
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusHeadline)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if !allSourcesOff && AppFeature.appUpdates.isAvailable {
                Button {
                    updates.check()
                } label: {
                    if updates.isChecking {
                        AnimatedEllipsisText(base: text.checking)
                    } else {
                        Text(hasError ? text.retry : text.checkNow)
                    }
                }
                .buttonStyle(.appManager(hasError && !updates.isChecking ? .accent : .neutral))
                .disabled(isBusy)
                .fixedSize()
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusTitleSkeleton: some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 3).frame(width: 170, height: 12)
            RoundedRectangle(cornerRadius: 3).frame(width: 120, height: 9)
        }
        .foregroundStyle(Color.primary.opacity(skeletonPulse ? 0.05 : 0.1))
        .padding(.vertical, 3)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                skeletonPulse = true
            }
        }
        .onDisappear { skeletonPulse = false }
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
