// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import AppKit
import SwiftUI

struct FeedbackView: View {
    let onClose: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var kind: FeedbackKind
    @State private var subject = ""
    @State private var message = ""
    @State private var includeDiagnostics = false
    @State private var draftOpened = false
    @State private var errorMessage: String?

    private let diagnostics = FeedbackDiagnostics.current()

    init(initialKind: FeedbackKind = .bug, onClose: @escaping () -> Void) {
        _kind = State(initialValue: initialKind)
        self.onClose = onClose
    }

    private var strings: FeedbackStrings { FeatureStrings.feedback(l10n.language) }
    private var draftStrings: FeedbackDraftStrings { .text(l10n.language) }
    private var count: Int { message.utf16.count }
    private var canSend: Bool {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!trimmedSubject.isEmpty || !trimmedMessage.isEmpty) && count <= 2_000
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if draftOpened {
                sentView
            } else {
                form
            }
        }
        .frame(width: 600, height: 680)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            Text(strings.windowTitle)
                .font(.title2.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("", selection: $kind) {
                        Text(strings.bugTitle).tag(FeedbackKind.bug)
                        Text(strings.featureTitle).tag(FeedbackKind.feature)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(strings.subjectLabel)
                            .font(.headline)
                        ZStack(alignment: .leading) {
                            if subject.isEmpty {
                                Text(kind == .bug ? strings.bugSubjectPlaceholder : strings.featureSubjectPlaceholder)
                                    .foregroundStyle(Color(nsColor: .placeholderTextColor))
                                    .allowsHitTesting(false)
                            }
                            TextField("", text: $subject)
                                .textFieldStyle(.plain)
                        }
                        .font(.body)
                        .padding(8)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(.separator, lineWidth: 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(kind == .bug ? strings.bugMessageLabel : strings.featureMessageLabel)
                            .font(.headline)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $message)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                            if message.isEmpty {
                                Text(kind == .bug ? strings.bugPlaceholder : strings.featurePlaceholder)
                                    .foregroundStyle(Color(nsColor: .placeholderTextColor))
                                    .padding(.horizontal, 11)
                                    .padding(.top, 6)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(minHeight: 130)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(.separator, lineWidth: 1)
                        }
                        Text(String(format: strings.charactersFormat, count))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(count > 2_000 ? .red : .secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(strings.includeDiagnostics)
                                    .font(.headline)
                                Text(strings.includeDiagnosticsCaption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $includeDiagnostics)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        if includeDiagnostics {
                            Divider()
                            diagnosticsPreview
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label(draftStrings.privacy, systemImage: "lock.shield")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label(draftStrings.review, systemImage: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.separator.opacity(0.4), lineWidth: 0.5)
                    }
                }
                .padding(24)
            }

            Divider()
            HStack(spacing: 12) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                Button(strings.cancel, action: onClose)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                Button(draftStrings.button) { send() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onChange(of: message) { oldValue, newValue in
            if newValue.utf16.count > 2_000 {
                var limited = ""
                var units = 0
                for character in newValue {
                    let piece = String(character)
                    let pieceUnits = piece.utf16.count
                    if units + pieceUnits > 2_000 { break }
                    limited.append(contentsOf: piece)
                    units += pieceUnits
                }
                message = limited.isEmpty ? oldValue : limited
            }
            if errorMessage != nil { errorMessage = nil }
        }
    }

    private var diagnosticsPreview: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
            diagnosticRow(DownstreamIdentity.name, "\(diagnostics.appVersion) (\(diagnostics.appBuild))")
            diagnosticRow("macOS", diagnostics.macOS)
            if let model = diagnostics.macModel { diagnosticRow("Mac", model) }
            diagnosticRow(l10n.s.languageLabel, diagnostics.language)
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.tertiary)
            Text(value).textSelection(.enabled)
        }
    }

    private var sentView: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 54))
                .foregroundStyle(.tint)
            Text(draftStrings.opened)
                .font(.title2.weight(.semibold))
            Text(draftStrings.openedCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button(strings.done, action: onClose)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func send() {
        guard canSend else { return }
        errorMessage = nil
        do {
            try FeedbackService.shared.openDraft(
                kind: kind,
                subject: subject,
                message: message,
                diagnostics: includeDiagnostics ? diagnostics : nil
            )
            draftOpened = true
        } catch FeedbackError.tooLong {
            errorMessage = draftStrings.tooLong
        } catch {
            errorMessage = draftStrings.error
        }
    }
}
