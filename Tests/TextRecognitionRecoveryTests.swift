// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum TextRecognitionRecoveryTests {
    enum Failure: Error { case initializing, invalidImage }
    static func run(_ suite: TestSuite) {
        var attempts: [TextRecognitionRecovery.Attempt] = []
        let recovered: Result<String, Error> = TextRecognitionRecovery.perform(
            retryable: { ($0 as? Failure) == .initializing }, pause: { _ in }) { attempt in
                attempts.append(attempt)
                if attempts.count == 1 { throw Failure.initializing }
                return "Recovered text"
            }
        suite.expect((try? recovered.get()) == "Recovered text" && attempts == [.initial, .retry],
                     "a temporarily unavailable recognizer recovers with a fresh recognition request")
        var terminalCalls = 0
        let invalid: Result<String, Error> = TextRecognitionRecovery.perform(
            retryable: { ($0 as? Failure) == .initializing }, pause: { _ in }) { _ in
                terminalCalls += 1; throw Failure.invalidImage
            }
        suite.expect((try? invalid.get()) == nil && terminalCalls == 1,
                     "invalid images fail once instead of blocking later queued recognition work")
        var unavailableCalls = 0
        let unavailable: Result<String, Error> = TextRecognitionRecovery.perform(
            retryable: { _ in true }, pause: { _ in }) { _ in
                unavailableCalls += 1; throw Failure.initializing
            }
        suite.expect((try? unavailable.get()) == nil && unavailableCalls == 3,
                     "persistent service failures have a bounded retry budget")
    }
}
