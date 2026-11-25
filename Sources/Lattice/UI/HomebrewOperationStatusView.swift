// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct HomebrewOperationStatusView: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDismissing = false

    let status: HomebrewOperationStatus
    let log: String
    let terminalFallbackCommand: String?
    let compact: Bool
    var cleanupSummary: HomebrewCleanupSummary? = nil
    @Binding var showDetails: Bool
    var onCancel: () -> Void
    var onClear: () -> Void
    var onOpenTerminal: () -> Void

    private var tabStrings: HomebrewTabStrings { FeatureStrings.homebrewTab(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            header
            progressArea
            if let summaryText = displayedActivity, !summaryText.isEmpty {
                Text(summaryText)
                    .font(.system(size: compact ? 9.5 : 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if status.result == .needsTerminal {
                terminalFallback
            }
            if !log.isEmpty {
                detailsToggle
            }
            if showDetails && !log.isEmpty {
                technicalLog
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: showDetails)
    }

    private var displayedActivity: String? {
        if status.action == .cleanup, status.result == .succeeded, let cleanupSummary {
            return cleanupSummary.freedSizeText.map { String(format: tabStrings.cleanupFreedFormat, $0) }
                ?? tabStrings.cleanupAlreadyClean
        }
        return status.lastActivity
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                Image(systemName: iconName)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: compact ? 11.5 : 13, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if status.isActive {
                        Text(phaseText)
                        Text("|")
                    }
                    TimelineView(.periodic(from: status.startedAt, by: 1)) { context in
                        Text(String(format: l10n.s.homebrewOperationElapsedFormat,
                                    elapsedText(now: context.date)))
                    }
                }
                .font(.system(size: compact ? 9.5 : 11))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if status.isActive {
                Button(l10n.s.homebrewCancelOperation) {
                    onCancel()
                }
                .controlSize(.mini)
            } else {
                Button(l10n.s.homebrewClearLog) {
                    dismiss()
                }
                .controlSize(.mini)
            }
        }
    }

    @ViewBuilder
    private var progressArea: some View {
        if status.isActive {
            if let fraction = status.progressFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
            } else {
                HomebrewIndeterminateProgressBar()
                Text(l10n.s.homebrewOperationProgressUnknown)
                    .font(.system(size: compact ? 9 : 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        } else if status.result == .succeeded {
            ProgressView(value: 1)
                .progressViewStyle(.linear)
        }
    }

    private var terminalFallback: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(l10n.s.homebrewTerminalFallback, systemImage: "terminal")
                .font(.system(size: compact ? 9.5 : 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if terminalFallbackCommand != nil {
                HStack(spacing: 8) {
                    Button(l10n.s.homebrewOpenTerminal) {
                        onOpenTerminal()
                    }
                    Button {
                        copy(terminalFallbackCommand)
                    } label: {
                        Label(l10n.s.menuCopy, systemImage: "doc.on.doc")
                    }
                }
                .controlSize(.small)
            }
        }
    }

    private var detailsToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                showDetails.toggle()
            }
        } label: {
            Label(showDetails ? l10n.s.homebrewOperationHideDetails : l10n.s.homebrewOperationShowDetails,
                  systemImage: showDetails ? "chevron.up" : "chevron.down")
                .font(.system(size: compact ? 10 : 11, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(log.isEmpty || isDismissing)
    }

    private func dismiss() {
        guard !isDismissing else { return }
        if showDetails && !reduceMotion {
            isDismissing = true
            withAnimation(.easeInOut(duration: 0.18)) {
                showDetails = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onClear()
                }
                isDismissing = false
            }
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                onClear()
            }
        }
    }

    private var technicalLog: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(l10n.s.homebrewOperationTechnicalLog)
                    .font(.system(size: compact ? 9.5 : 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button {
                    copy(log)
                } label: {
                    Label(l10n.s.menuCopy, systemImage: "doc.on.doc")
                }
                .controlSize(.mini)
                .disabled(log.isEmpty)
            }
            ScrollView {
                Text(log.isEmpty ? " " : log)
                    .font(.system(size: compact ? 9 : 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: compact ? 58 : 96)
        }
    }

    private var title: String {
        switch status.result {
        case .running:
            if status.action == .updateHomebrew {
                return l10n.s.homebrewOperationUpdateHomebrew
            }
            if status.action == .upgradeAll {
                return l10n.s.homebrewOperationUpgradeAll
            }
            if status.action == .cleanup {
                return tabStrings.operationCleaning
            }
            return String(format: runningTitleFormat, packageDisplayName)
        case .succeeded:
            if status.action == .updateHomebrew {
                return l10n.s.homebrewOperationUpdatedHomebrew
            }
            if status.action == .upgradeAll {
                return l10n.s.homebrewOperationUpgradedAll
            }
            if status.action == .cleanup {
                return tabStrings.operationCleaned
            }
            return String(format: succeededTitleFormat, packageDisplayName)
        case .failed:
            return String(format: l10n.s.homebrewOperationFailedFormat, packageDisplayName)
        case .cancelled:
            return l10n.s.homebrewOperationCancelled
        case .needsTerminal:
            return l10n.s.homebrewOperationTerminal
        }
    }

    private var phaseText: String {
        switch status.result {
        case .cancelled:
            return l10n.s.homebrewOperationCancelled
        case .failed:
            return String(format: l10n.s.homebrewOperationFailedFormat, packageDisplayName)
        case .needsTerminal:
            return l10n.s.homebrewOperationTerminal
        case .running, .succeeded:
            switch status.phase {
            case .preparing: return l10n.s.homebrewOperationPreparing
            case .downloading: return l10n.s.homebrewOperationDownloading
            case .installing: return l10n.s.homebrewOperationInstalling
            case .uninstalling: return l10n.s.homebrewOperationUninstalling
            case .upgrading: return l10n.s.homebrewOperationUpgrading
            case .cleaning: return tabStrings.cleaningPhase
            case .finalizing: return l10n.s.homebrewOperationFinalizing
            case .refreshing: return l10n.s.homebrewOperationRefreshing
            }
        }
    }

    private var runningTitleFormat: String {
        switch status.action {
        case .install: return l10n.s.homebrewOperationInstallFormat
        case .uninstall: return l10n.s.homebrewOperationUninstallFormat
        case .upgrade: return l10n.s.homebrewOperationUpgradeFormat
        case .upgradeAll: return l10n.s.homebrewOperationUpgradeAll
        case .updateHomebrew: return l10n.s.homebrewOperationUpdateHomebrew
        case .cleanup: return tabStrings.operationCleaning
        }
    }

    private var succeededTitleFormat: String {
        switch status.action {
        case .install: return l10n.s.homebrewOperationInstalledFormat
        case .uninstall: return l10n.s.homebrewOperationUninstalledFormat
        case .upgrade: return l10n.s.homebrewOperationUpgradedFormat
        case .upgradeAll: return l10n.s.homebrewOperationUpgradedAll
        case .updateHomebrew: return l10n.s.homebrewOperationUpdatedHomebrew
        case .cleanup: return tabStrings.operationCleaned
        }
    }

    private var packageDisplayName: String {
        if let name = status.package?.displayName { return name }
        switch status.action {
        case .updateHomebrew: return l10n.s.homebrewName
        case .cleanup: return tabStrings.cleanupTitle
        default: return l10n.s.homebrewAllPackages
        }
    }

    private var iconName: String {
        switch status.result {
        case .running: return status.action.runningSystemImage
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.octagon.fill"
        case .needsTerminal: return "terminal.fill"
        }
    }

    private var iconColor: Color {
        switch status.result {
        case .running: return .accentColor
        case .succeeded: return .green
        case .failed, .needsTerminal: return .orange
        case .cancelled: return .red
        }
    }

    private func elapsedText(now: Date) -> String {
        let end = status.finishedAt ?? now
        let seconds = max(Int(end.timeIntervalSince(status.startedAt)), 0)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)min"
        }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)min"
    }

    private func copy(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareLatticeSource()
        pasteboard.setString(text, forType: .string)
    }
}

struct HomebrewIndeterminateProgressBar: View {
    @State private var offset: CGFloat = -0.35

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(Color.accentColor.opacity(0.72))
                    .frame(width: max(geometry.size.width * 0.34, 36))
                    .offset(x: offset * geometry.size.width)
            }
            .clipped()
        }
        .frame(height: 5)
        .onAppear {
            offset = -0.35
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                offset = 1.05
            }
        }
    }
}

/// Compact operation footer shared identically by the floating Hub and Settings
/// Homebrew page, with toggleable monospaced log drawer.
struct HomebrewCompactOperationFooter: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDismissing = false
    @State private var displayedLog = ""

    let status: HomebrewOperationStatus

    private var s: Strings { l10n.s }
    private var tabStrings: HomebrewTabStrings { FeatureStrings.homebrewTab(l10n.language) }
    private var effectiveLog: String { homebrew.log.isEmpty ? displayedLog : homebrew.log }
    private var showsLogDrawer: Bool { homebrew.isOperationDetailsExpanded && !effectiveLog.isEmpty }
    private static let logDrawerExpandedHeight: CGFloat = 82

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if status.isActive {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(operationTitle)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                        Text(status.lastActivity ?? "$ " + commandLine)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 6)
                    Button(s.homebrewCancelOperation) {
                        homebrew.cancelOperation()
                    }
                    .buttonStyle(.appManager(.neutral, compact: true))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: resultIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(resultColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(completedTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        if let detail = completedSubtitle {
                            Text(detail)
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer(minLength: 6)
                    if status.result == .needsTerminal, homebrew.terminalFallbackCommand != nil {
                        Button(s.homebrewOpenTerminal) {
                            homebrew.openTerminalFallback()
                        }
                        .buttonStyle(.appManager(compact: true))
                    }
                    if !homebrew.log.isEmpty {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                                homebrew.setOperationDetailsExpanded(!homebrew.isOperationDetailsExpanded)
                            }
                        } label: {
                            Image(systemName: homebrew.isOperationDetailsExpanded ? "chevron.down" : "text.alignleft")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .disabled(isDismissing)
                        .help(homebrew.isOperationDetailsExpanded
                              ? s.homebrewOperationHideDetails
                              : s.homebrewOperationShowDetails)
                    }
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(s.homebrewClearLog)
                }
                if !effectiveLog.isEmpty {
                    logDrawer(effectiveLog)
                        .padding(.top, 6)
                        .frame(height: showsLogDrawer ? Self.logDrawerExpandedHeight : 0, alignment: .top)
                        .opacity(showsLogDrawer ? 1 : 0)
                        .clipped()
                        .allowsHitTesting(showsLogDrawer)
                        .accessibilityHidden(!showsLogDrawer)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: showsLogDrawer)
        .onAppear {
            if !homebrew.log.isEmpty {
                displayedLog = homebrew.log
            }
        }
        .onChange(of: homebrew.log) { _, newValue in
            if !newValue.isEmpty {
                displayedLog = newValue
            }
        }
    }

    private func logDrawer(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 24)
        }
        .frame(height: 64)
        .padding(6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.declareLatticeSource()
                pasteboard.setString(text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(4)
            .help(s.menuCopy)
            .accessibilityLabel(s.menuCopy)
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        if homebrew.isOperationDetailsExpanded && !reduceMotion {
            isDismissing = true
            withAnimation(.easeInOut(duration: 0.18)) {
                homebrew.setOperationDetailsExpanded(false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    homebrew.clearLog()
                }
                isDismissing = false
            }
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                homebrew.clearLog()
            }
        }
    }

    private var targetDisplayName: String {
        if let name = status.package?.displayName { return name }
        switch status.action {
        case .updateHomebrew: return s.homebrewName
        case .cleanup: return tabStrings.cleanupTitle
        default: return s.homebrewAllPackages
        }
    }

    private var operationTitle: String {
        let name = status.package?.displayName ?? ""
        switch status.action {
        case .install: return String(format: s.homebrewOperationInstallFormat, name)
        case .uninstall: return String(format: s.homebrewOperationUninstallFormat, name)
        case .upgrade: return String(format: s.homebrewOperationUpgradeFormat, name)
        case .upgradeAll: return s.homebrewOperationUpgradeAll
        case .updateHomebrew: return s.homebrewOperationUpdateHomebrew
        case .cleanup: return tabStrings.operationCleaning
        }
    }

    private var completedTitle: String {
        let name = status.package?.displayName ?? ""
        switch status.result {
        case .running:
            return operationTitle
        case .succeeded:
            switch status.action {
            case .install: return String(format: s.homebrewOperationInstalledFormat, name)
            case .uninstall: return String(format: s.homebrewOperationUninstalledFormat, name)
            case .upgrade: return String(format: s.homebrewOperationUpgradedFormat, name)
            case .upgradeAll: return s.homebrewOperationUpgradedAll
            case .updateHomebrew: return s.homebrewOperationUpdatedHomebrew
            case .cleanup: return tabStrings.operationCleaned
            }
        case .failed:
            return String(format: s.homebrewOperationFailedFormat, targetDisplayName)
        case .cancelled:
            return s.homebrewOperationCancelled
        case .needsTerminal:
            return s.homebrewOperationTerminal
        }
    }

    private var completedSubtitle: String? {
        if status.result == .succeeded {
            guard status.action == .cleanup, let summary = homebrew.lastCleanupSummary else { return nil }
            return summary.freedSizeText.map { String(format: tabStrings.cleanupFreedFormat, $0) }
                ?? tabStrings.cleanupAlreadyClean
        }
        return status.lastActivity ?? homebrew.errorMessage
    }

    private var commandLine: String {
        let cask = status.package?.kind == .cask ? "--cask " : ""
        let name = status.package?.name ?? ""
        switch status.action {
        case .install: return "brew install \(cask)\(name)"
        case .uninstall: return "brew uninstall \(cask)\(name)"
        case .upgrade: return "brew upgrade \(cask)\(name)"
        case .upgradeAll: return "brew upgrade"
        case .updateHomebrew: return "brew update"
        case .cleanup: return "brew cleanup --prune=all -s"
        }
    }

    private var resultIcon: String {
        switch status.result {
        case .running: return "hourglass"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.octagon.fill"
        case .needsTerminal: return "terminal.fill"
        }
    }

    private var resultColor: Color {
        switch status.result {
        case .running: return .accentColor
        case .succeeded: return .green
        case .failed, .needsTerminal: return .orange
        case .cancelled: return .red
        }
    }
}
