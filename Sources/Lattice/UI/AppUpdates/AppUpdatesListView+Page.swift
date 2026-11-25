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

                availableUpdatesHeader
                pageResults

                // After the list, never sliding in over it: what the check
                // could not reach is a footnote to what it found.
                if coverageIncomplete {
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
            // One animation for the column, so the notice under the list
            // moves with the rows when one leaves.
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: updates.items)
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
        UpdatesHeading(text: text, count: updates.items.count, lastCheck: headingDetail,
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
        } else if updates.isChecking && updates.items.isEmpty {
            skeletonSection
                .transition(reduceMotion ? .identity : .opacity)
        } else if !updates.items.isEmpty {
            // A row that leaves folds away, so the rows below close the gap
            // instead of sliding under it.
            VStack(spacing: 8) {
                ForEach(updates.items) { item in
                    row(item)
                        .transition(reduceMotion ? .identity : .settingsReveal)
                }
            }
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

    var skeletonSection: some View {
        VStack(spacing: 8) {
            skeletonRow(titleWidth: 130, subtitleWidth: 90)
            skeletonRow(titleWidth: 100, subtitleWidth: 70)
            skeletonRow(titleWidth: 150, subtitleWidth: 110)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                skeletonPulse = true
            }
        }
        .onDisappear { skeletonPulse = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.checking)
    }

    func skeletonRow(titleWidth: CGFloat, subtitleWidth: CGFloat) -> some View {
        let shimmerOpacity = skeletonPulse ? 0.08 : 0.04
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(shimmerOpacity))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(shimmerOpacity))
                    .frame(width: titleWidth, height: 12)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.primary.opacity(shimmerOpacity * 0.75))
                    .frame(width: subtitleWidth, height: 10)
            }

            Spacer(minLength: 8)

            Capsule()
                .fill(Color.primary.opacity(shimmerOpacity))
                .frame(width: 72, height: 24)

            Circle()
                .fill(Color.primary.opacity(shimmerOpacity * 0.7))
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }

    // Status Card
    // MARK: - Update Sources

}
