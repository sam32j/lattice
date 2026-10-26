// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum FeedbackDraftTests {
    static func run(_ suite: TestSuite) {
        do {
            let url = try FeedbackDraft.url(kind: .bug, message: "  Windows & tabs? #1 + 中文\nNext line  ", diagnostics: nil)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            suite.expect(components.scheme == "https" && components.host == "github.com"
                         && components.path == "/sam32j/lattice/issues/new", "feedback opens a Lattice issue draft")
            suite.expect(items["body"] == "## Bug report\n\nWindows & tabs? #1 + 中文\nNext line",
                         "the issue draft preserves punctuation, Unicode and line breaks without diagnostics")
            suite.expect(!url.absoluteString.contains("+"),
                         "literal plus signs are escaped so GitHub form decoding cannot turn them into spaces")
        } catch { suite.expect(false, "valid feedback produces an issue draft: \(error)") }
        do {
            let details = FeedbackDiagnostics(appVersion: "1.2.3", appBuild: "42", macOS: "26.0",
                                              macModel: nil, language: "de", isBeta: false, updateChannel: "developer")
            let url = try FeedbackDraft.url(kind: .feature, message: "Please add a useful feature", diagnostics: details)
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
            let body = items.first { $0.name == "body" }!.value!
            suite.expect(body.contains("## Feature request") && body.contains("- Lattice: 1.2.3 (42)")
                         && body.contains("- macOS: 26.0") && body.contains("- Language: de")
                         && !body.contains("- Beta:") && !body.contains("- Update channel:")
                         && !body.contains("- Mac:"), "only selected diagnostics appear and absent model is omitted")
            let maximum = try FeedbackDraft.url(kind: .bug, message: String(repeating: "a", count: 2_000), diagnostics: nil)
            suite.expect(maximum.host == "github.com", "the full ASCII message limit can be drafted")
            try FeedbackDraft.open(kind: .bug, message: "Open this valid report", diagnostics: nil, using: { _ in true })
            suite.expect(true, "browser acceptance completes the draft handoff without submitting an issue")

            let withSubject = try FeedbackDraft.url(kind: .bug, subject: "App freezes", message: "Short", diagnostics: nil)
            let withSubjectItems = URLComponents(url: withSubject, resolvingAgainstBaseURL: false)!.queryItems!
            let titleWithSubject = withSubjectItems.first { $0.name == "title" }!.value!
            suite.expect(titleWithSubject == "[Bug report] App freezes", "subject is included in issue title")

            let subjectOnly = try FeedbackDraft.url(kind: .feature, subject: "Add dark mode", message: "", diagnostics: nil)
            let subjectOnlyItems = URLComponents(url: subjectOnly, resolvingAgainstBaseURL: false)!.queryItems!
            let titleSubjectOnly = subjectOnlyItems.first { $0.name == "title" }!.value!
            suite.expect(titleSubjectOnly == "[Feature request] Add dark mode", "subject without message generates title")
        } catch { suite.expect(false, "valid draft handoff: \(error)") }
        for invalid in ["", "   \n   ", String(repeating: "a", count: 2_001)] {
            do {
                try FeedbackDraft.open(kind: .bug, message: invalid, diagnostics: nil, using: { _ in
                    suite.expect(false, "invalid feedback never reaches the browser")
                    return true
                })
                suite.expect(false, "invalid message rejected")
            } catch FeedbackError.rejected { suite.expect(true, "invalid message rejected before browser handoff") }
            catch { suite.expect(false, "unexpected invalid-message error: \(error)") }
        }
        do {
            _ = try FeedbackDraft.url(kind: .bug, message: String(repeating: "字", count: 2_000), diagnostics: nil)
            suite.expect(false, "oversized encoded URL must fail explicitly")
        } catch FeedbackError.tooLong { suite.expect(true, "encoded Unicode size is bounded") }
        catch { suite.expect(false, "unexpected size error: \(error)") }
        do {
            try FeedbackDraft.open(kind: .bug, message: "Open this valid report", diagnostics: nil, using: { _ in false })
            suite.expect(false, "browser failure must not report a successful handoff")
        } catch FeedbackError.unavailable { suite.expect(true, "browser failure remains observable") }
        catch { suite.expect(false, "unexpected browser error: \(error)") }
        for language in AppLanguage.allCases {
            let copy = FeedbackDraftStrings.text(language)
            suite.expect(!copy.button.isEmpty && copy.privacy.contains("GitHub") && !copy.review.isEmpty
                         && !copy.opened.isEmpty && !copy.openedCaption.isEmpty && !copy.error.isEmpty
                         && !copy.tooLong.isEmpty, "draft privacy, status and failure copy exists for \(language)")
        }

        suite.expect(FeedbackDraft.validationError(kind: .bug, subject: "Useful title", message: "", diagnostics: nil) == nil,
                     "a valid subject-only draft enables the handoff")
        suite.expect(FeedbackDraft.validationError(kind: .bug, subject: String(repeating: "字", count: 1_000),
                     message: "", diagnostics: nil) == .tooLong,
                     "an encoded subject that exceeds the URL budget is rejected before handoff")
        let boundaryTitle = String(repeating: "a", count: 7_800)
        let longDetails = FeedbackDiagnostics(appVersion: "1", appBuild: "1", macOS: "26",
            macModel: String(repeating: "M", count: 300), language: "en", isBeta: false, updateChannel: "stable")
        suite.expect(FeedbackDraft.validationError(kind: .bug, subject: boundaryTitle, message: "", diagnostics: nil) == nil
                     && FeedbackDraft.validationError(kind: .bug, subject: boundaryTitle, message: "", diagnostics: longDetails) == .tooLong,
                     "the selected diagnostics consume the same URL budget used by Send validation")
        suite.expect(FeedbackDraft.validationError(kind: .bug, message: "  ", diagnostics: nil) == .rejected,
                     "an empty draft stays disabled")

        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let settings = CGRect(x: 300, y: 200, width: 700, height: 500)
        let frameOnSettings = FeedbackWindowGeometry.targetFrame(settingsFrame: settings, visibleFrame: visible)
        suite.expect(frameOnSettings.size == FeedbackWindowGeometry.size
                     && frameOnSettings.midX == settings.midX
                     && frameOnSettings.midY == settings.midY,
                     "feedback window is centered on top of settings window")

        let offscreenSettings = CGRect(x: -200, y: -200, width: 500, height: 400)
        let clampedFrame = FeedbackWindowGeometry.targetFrame(settingsFrame: offscreenSettings, visibleFrame: visible)
        suite.expect(clampedFrame.minX >= visible.minX && clampedFrame.minY >= visible.minY
                     && clampedFrame.maxX <= visible.maxX && clampedFrame.maxY <= visible.maxY,
                     "feedback window is clamped within visible screen frame")

        let standalone = FeedbackWindowGeometry.targetFrame(settingsFrame: nil, visibleFrame: visible)
        suite.expect(standalone.midX == visible.midX && standalone.midY == visible.midY,
                     "feedback window centers on active visible screen when settings is hidden")
    }
}
