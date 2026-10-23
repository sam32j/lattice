import Foundation

/// The only external boundary: a real SDK in production, deterministic files in tests.
struct MediaOptimizerClient {
    var optimize: (URL, Bool, URL) throws -> URL
    var cancel: () -> Void
    static var live: MediaOptimizerClient {
        let encoder = NativeMediaOptimizer()
        return MediaOptimizerClient(optimize: { try encoder.optimize($0, aggressive: $1, directory: $2) },
                                    cancel: { encoder.cancel() })
    }
}
