// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Bounded recovery at the external recognition-engine boundary. Each retry
/// creates a fresh request rather than reusing the failed Vision object.
enum TextRecognitionRecovery {
    enum Attempt { case initial, retry }
    static func perform<Value>(retryable: (Error) -> Bool,
                               pause: (TimeInterval) -> Void,
                               operation: (Attempt) throws -> Value) -> Result<Value, Error> {
        let attempts: [Attempt] = [.initial, .retry, .retry]
        for (index, attempt) in attempts.enumerated() {
            do { return .success(try operation(attempt)) }
            catch {
                guard retryable(error), index < attempts.count - 1 else { return .failure(error) }
                pause(index == 0 ? 0.15 : 0.35)
            }
        }
        preconditionFailure("The final failed attempt must return its error.")
    }
}
