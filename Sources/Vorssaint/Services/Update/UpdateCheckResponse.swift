// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum UpdateCheckResponse {
    static func failure(response: URLResponse?, error: Error?) -> String? {
        if let error { return error.localizedDescription }
        guard let response = response as? HTTPURLResponse else {
            return URLError(.badServerResponse).localizedDescription
        }
        guard (200..<300).contains(response.statusCode) else {
            return "\(HTTPURLResponse.localizedString(forStatusCode: response.statusCode)) (HTTP \(response.statusCode))"
        }
        return nil
    }
}
