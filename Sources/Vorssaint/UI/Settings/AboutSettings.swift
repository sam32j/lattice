// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

// MARK: - About

struct AboutSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showingReleaseNotes = false

    private var feedbackStrings: FeedbackStrings { FeatureStrings.feedback(l10n.language) }

    var body: some View {
        Form {
            Section {
                aboutContent
            }

            Section(feedbackStrings.sectionTitle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feedbackStrings.sectionTitle)
                            .font(.body)
                        Text(feedbackStrings.sectionCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(feedbackStrings.openButton) {
                        appDelegate()?.openFeedbackWindow()
                    }
                }
                .padding(.vertical, 4)
            }

            UpdatesView()
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingReleaseNotes) {
            ReleaseNotesSettings()
                .frame(width: 620, height: 600)
        }
    }

    private var aboutContent: some View {
        VStack(spacing: 14) {
            BrandBadge(size: 76)
            VStack(spacing: 3) {
                Text(AppInfo.name)
                    .font(.title2.bold())
                HStack(spacing: 6) {
                    Text("\(l10n.s.versionPrefix) \(AppInfo.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if AppInfo.isBeta {
                        Text(l10n.s.betaBadgeLabel)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                if AppInfo.isDeveloperBuild, let commit = AppInfo.buildCommit {
                    // Dev-only: which source commit this build came from. Never shipped.
                    Text(commit)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
            HStack(spacing: 12) {
                Button {
                    showingReleaseNotes = true
                } label: {
                    Label(UpdateSettingsStrings.localized(l10n.language).changelog,
                          systemImage: "doc.text.magnifyingglass")
                }
                Button {
                    NSWorkspace.shared.open(AppInfo.repositoryURL)
                } label: {
                    Label("GitHub", systemImage: "link")
                }
            }
            Text("©️ Lattice")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
