// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var overhauledBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                updateSourcesSection

                preferencesSection

                // One loader while a check runs; the heading and list wait
                // for its answer, as in the Hub.
                if updates.isChecking {
                    pageLoader
                        .transition(reduceMotion ? .identity : .opacity)
                } else {
                    availableUpdatesHeader
                    pageResults
                }

                // After the list, never sliding in over it: what the check
                // could not reach is a footnote to what it found.
                if coverageIncomplete && !updates.isChecking {
                    pageIncompleteNote
                }

                if let status = appUpdatesOperationStatus {
                    HomebrewOperationStatusView(status: status,
                                                log: homebrew.log,
                                                terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                                compact: false,
                                                showDetails: $showOperationDetails,
                                                onCancel: homebrew.cancelOperation,
                                                onClear: homebrew.clearLog,
                                                onOpenTerminal: homebrew.openTerminalFallback)
                        .padding(.top, 6)
                        .transition(.settingsReveal)
                }
            }
            // The App Manager's tabs share one column width and margins.
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // The one driver for the notify row's reveal, whichever window or
        // control changed the frequency.
        .settingsExpansionAnimation(value: showsNotifyRow)
        .sheet(isPresented: $showingALS) {
            alsSheet
        }
        .onChange(of: statusHeadline) { _, newHeadline in
            AccessibilityNotification.Announcement("\(newHeadline), \(statusDetail)").post()
        }
    }

    /// Which apps the check left out, laid out as an update row is: the
    /// mark the size of an app icon, the text where an app's name starts.
    var pageIncompleteNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(text.incompleteCheck)
                    .font(.system(size: 13, weight: .semibold))
                Text(incompleteCheckDetail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if storeCoverageIncomplete {
                Button(text.openAppStore) { updates.openAppStoreUpdates() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// The list's heading carries when it was last checked and the way to
    /// check again, rather than a card of its own.
    var availableUpdatesHeader: some View {
        UpdatesHeading(text: text, count: updates.items.count, lastCheck: lastCheckLine,
                       isChecking: updates.isChecking,
                       disabled: !AppFeature.appUpdates.isAvailable || allSourcesOff) { updates.check() }
            .padding(.horizontal, 2)
            .padding(.top, 6)
    }

    @ViewBuilder
    var pageResults: some View {
        if allSourcesOff {
            noSourcesCard
                .transition(reduceMotion ? .identity : .opacity)
        } else if !updates.items.isEmpty {
            LazyVStack(spacing: 8) {
                ForEach(updates.items) { item in
                    row(item)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: updates.items)
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

    var pageLoader: some View {
        VStack(spacing: 10) {
            if reduceMotion {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.regular)
            }
            Text(text.checking + "…")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .accessibilityElement(children: .combine)
    }

    // Status Card
    // MARK: - Update Sources

}
