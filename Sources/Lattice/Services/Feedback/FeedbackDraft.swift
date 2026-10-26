// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum FeedbackKind: String, Codable, CaseIterable {
    case bug
    case feature
}

struct FeedbackDiagnostics: Codable {
    let appVersion: String
    let appBuild: String
    let macOS: String
    let macModel: String?
    let language: String
    let isBeta: Bool
    let updateChannel: String
}

enum FeedbackError: Error {
    case rejected
    case tooLong
    case unavailable
}

enum FeedbackDraft {
    static func url(kind: FeedbackKind, subject: String = "", message: String, diagnostics: FeedbackDiagnostics?) throws -> URL {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!trimmed.isEmpty || !trimmedSubject.isEmpty) && trimmed.utf16.count <= 2_000 else { throw FeedbackError.rejected }
        let category = kind == .bug ? "Bug report" : "Feature request"
        var body = "## \(category)\n\n"
        if !trimmed.isEmpty {
            body += "\(trimmed)\n\n"
        }
        if let details = diagnostics {
            body += "## Technical details\n\n"
            body += "- Lattice: \(details.appVersion) (\(details.appBuild))\n"
            body += "- macOS: \(details.macOS)\n"
            if let model = details.macModel { body += "- Mac: \(model)\n" }
            body += "- Language: \(details.language)\n"
        }
        let title = trimmedSubject.isEmpty ? "[\(category)]" : "[\(category)] \(trimmedSubject)"
        var components = URLComponents(string: "https://github.com/\(DownstreamIdentity.repository)/issues/new")!
        components.queryItems = [URLQueryItem(name: "title", value: title),
                                 URLQueryItem(name: "body", value: body.trimmingCharacters(in: .whitespacesAndNewlines))]
        // GitHub decodes form-style queries, where a literal '+' otherwise means a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw FeedbackError.rejected }
        // Use a conservative encoded URL budget, including Unicode expansion.
        guard url.absoluteString.utf8.count <= 8_000 else { throw FeedbackError.tooLong }
        return url
    }

    static func open(kind: FeedbackKind, subject: String = "", message: String, diagnostics: FeedbackDiagnostics?,
                     using openURL: (URL) -> Bool) throws {
        let draft = try url(kind: kind, subject: subject, message: message, diagnostics: diagnostics)
        guard openURL(draft) else { throw FeedbackError.unavailable }
    }
}
