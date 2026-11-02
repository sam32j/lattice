// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var overhauledBody: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                statusCard

                updateSourcesSection

                preferencesSection

                availableUpdatesHeader

                if allSourcesOff {
                    noSourcesCard
                        .transition(reduceMotion ? .identity : .opacity)
                } else if updates.isChecking && updates.items.isEmpty {
                    skeletonSection
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

                if let status = homebrew.operationStatus {
                    HomebrewOperationStatusView(status: status,
                                                log: homebrew.log,
                                                terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                                compact: false,
                                                showDetails: $showOperationDetails,
                                                onCancel: homebrew.cancelOperation,
                                                onClear: homebrew.clearLog,
                                                onOpenTerminal: homebrew.openTerminalFallback)
                        .padding(.top, 6)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingALS) {
            alsSheet
        }
        .onChange(of: statusHeadline) { _, newHeadline in
            AccessibilityNotification.Announcement("\(newHeadline), \(statusDetail)").post()
        }
    }

    var availableUpdatesHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.availableUpdatesTitle)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if !updates.items.isEmpty {
                Text(String(format: text.appCountFormat, updates.items.count))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            } else if updates.isChecking {
                Text(text.checking)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            } else if !allSourcesOff && updates.hasCheckedThisSession {
                Text(String(format: text.appCountFormat, 0))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
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
    var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(statusHeadline)
                    .font(.system(size: 14, weight: .semibold))
                Text(statusDetail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(statusHeadline), \(statusDetail)")

            Spacer(minLength: 16)

            Button {
                updates.check()
            } label: {
                HStack(spacing: 5) {
                    if updates.isChecking {
                        if reduceMotion {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(text.checking)
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text(text.checkNow)
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundStyle(updates.isChecking || !AppFeature.appUpdates.isAvailable || allSourcesOff ? Color.secondary.opacity(0.6) : Color.primary.opacity(0.85))
            }
            .buttonStyle(.plain)
            .disabled(updates.isChecking || !AppFeature.appUpdates.isAvailable || allSourcesOff)
            .accessibilityLabel(updates.isChecking ? text.checking : text.checkNow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Update Sources

}
