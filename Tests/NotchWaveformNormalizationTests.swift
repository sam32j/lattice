import Foundation

enum NotchWaveformNormalizationTests {
    static func run(_ suite: TestSuite) {
        func expect(_ value: Bool, _ message: String) { suite.expect(value, message) }
        var balanced = NotchAudioLevelSupport.Smoother()
        var spectrum: [Double] = []
        for _ in 0..<40 { spectrum = balanced.next([0.9, 0.7, 0.5, 0.35, 0.25, 0.18, 0.12]) }
        expect(spectrum[6] / spectrum[0] > 0.25 && spectrum[0] > spectrum[6],
               "adaptive band normalization reduces bass dominance without flattening the spectrum")
        var sparse = NotchAudioLevelSupport.Smoother()
        for _ in 0..<40 { spectrum = sparse.next([0.9, 0, 0, 0, 0, 0, 0]) }
        expect(spectrum.dropFirst().allSatisfy { $0 == 0 }, "normalization never invents energy in silent bands")
    }
}
