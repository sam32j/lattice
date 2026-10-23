import Foundation

/// The native OS/encoder boundary; tests may provide deterministic files.
struct MediaOptimizerClient {
    var optimize: (URL, Bool, URL) throws -> URL
    var cancel: () -> Void
    var convert: ((URL, MediaOutputFormat, Bool, URL) throws -> URL)? = nil
    static var live: MediaOptimizerClient {
        let encoder = NativeMediaOptimizer()
        return MediaOptimizerClient(optimize: { try encoder.optimize($0, aggressive: $1, directory: $2) },
            cancel: { encoder.cancel() }, convert: { try encoder.optimize($0, aggressive: $2, directory: $3, format: $1) })
    }
}
