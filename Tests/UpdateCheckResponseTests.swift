// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum UpdateCheckResponseTests {
    static func run(_ expect: (Bool, String) -> Void) {
        let url = URL(string: "https://example.invalid/releases")!
        let denied = HTTPURLResponse(url: url, statusCode: 403,
                                     httpVersion: nil, headerFields: nil)!
        expect(UpdateCheckResponse.failure(response: denied, error: nil)?.contains("HTTP 403") == true,
               "an HTTP failure names its status instead of displaying a dash")
        let success = HTTPURLResponse(url: url, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
        expect(UpdateCheckResponse.failure(response: success, error: nil) == nil,
               "a successful HTTP response proceeds to release parsing")
        let offline = URLError(.notConnectedToInternet)
        expect(UpdateCheckResponse.failure(response: denied, error: offline)
               == offline.localizedDescription,
               "a transport failure retains its actionable system explanation")
        expect(UpdateCheckResponse.failure(response: nil, error: nil)?.isEmpty == false,
               "a missing HTTP response has a meaningful failure explanation")
    }
}
