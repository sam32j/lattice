import Foundation

/// The executor is the process boundary. Tests supply an in-process executor;
/// production uses the bounded runner's race-safe launch cancellation.
enum FeatureReadProcess {
    struct Request {
        let path: String
        let arguments: [String]
        let timeout: TimeInterval
        let environment: [String: String]?
    }
    typealias Executor = (Request, BoundedProcessCancellation) -> BoundedProcessRunner.Result

    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 30,
                    environment: [String: String]? = nil,
                    cancellation: FeatureWorkCancellation,
                    executor: Executor = native) -> (status: Int32, output: String) {
        guard !cancellation.isCancelled else { return (-1, "") }
        let child = BoundedProcessCancellation()
        let registration = cancellation.register { child.cancel() }
        defer { cancellation.remove(registration) }
        let result = executor(Request(path: path, arguments: arguments, timeout: timeout,
            environment: environment), child)
        guard !cancellation.isCancelled else { return (-1, "") }
        return (result.status, String(data: result.output, encoding: .utf8) ?? "")
    }

    private static func native(_ request: Request, _ cancellation: BoundedProcessCancellation) -> BoundedProcessRunner.Result {
        BoundedProcessRunner.run(request.path, request.arguments, timeout: request.timeout,
            maxOutputBytes: 32 * 1_024 * 1_024, environment: request.environment, cancellation: cancellation)
    }
}
