// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum VideoDownloadProgressTests {
    static func run(_ suite: TestSuite) {
        var tracker = VideoDownloadProgressTracker()
        _ = tracker.consume(#"LATTICE_PARTS:[{"format_id":"video"},{"format_id":"audio"}]"#)
        func line(_ percent: String, _ bytes: String = "NA", _ total: String = "NA",
                  fragment: String = "NA", count: String = "NA", status: String = "downloading", id: String = "video") -> String {
            "LATTICE_PROGRESS:\(percent)|\(bytes)|\(total)|1000|10|\(fragment)|\(count)|\(status)|\"\(id)\""
        }
        let fractions = [line("20%", "20", "100"), line("15%", "30", "200"),
                         line("25%", "50", "200"), line("18%", "54", "300")]
            .compactMap { tracker.consume($0)?.fraction }
        suite.expect(fractions == [0.1, 0.1, 0.125, 0.125],
                     "revised stream sizes do not move the whole-job progress backwards")
        suite.expect(tracker.consume(line("100%", "300", "300", status: "finished"))?.fraction == 0.5
                     && !tracker.isFinishing,
                     "finishing video reserves progress for its separate audio stream")
        suite.expect(tracker.consume(line("0%", "0", "100", id: "audio"))?.fraction == 0.5,
                     "starting audio does not reset overall progress")
        suite.expect(tracker.consume(line("50%", "50", "100", id: "audio"))?.fraction == 0.75,
                     "audio advances the remaining part of the overall progress bar")
        let final = tracker.consume(line("100%", "100", "100", status: "finished", id: "audio"))
        suite.expect(final?.fraction == 0.99 && final?.percentText == "99%" && tracker.isFinishing,
                     "all transfers enter finishing without claiming publication has already succeeded")
        suite.expect(final?.downloadedBytes == 400 && final?.totalBytes == 400,
                     "byte details summarize both streams")

        var fragments = VideoDownloadProgressTracker()
        _ = fragments.consume(#"LATTICE_PARTS:[{"format_id":"video"},{"format_id":"audio"}]"#)
        suite.expect(fragments.consume(line("100%", "712", fragment: "0", count: "59"))?.fraction == 0,
                     "a 100-percent HLS initialization fragment is not the whole video")
        let first = fragments.consume(line("0.8%", "712", fragment: "1", count: "59"))
        let retry = fragments.consume(line("100%", "0", fragment: "0", count: "59"))
        suite.expect(abs((first?.fraction ?? -1) - 1.0 / 118) < 0.000001 && retry?.fraction == first?.fraction,
                     "fragment counts advance steadily and retries preserve completed work")
        suite.expect(fragments.consume(line("NA", "900", fragment: "2", count: "59")) != nil,
                     "usable fragment progress is accepted when the tool has no percentage")
        suite.expect(fragments.consume("unrelated output") == nil && fragments.consume(line("nan")) == nil,
                     "unrelated or nonfinite progress is ignored")

        var recorded = VideoDownloadProgressTracker()
        let capture = (try? String(contentsOfFile: "Tests/Fixtures/VideoDownloader/hls-progress.log", encoding: .utf8)) ?? ""
        let recordedFractions = capture.split(separator: "\n").compactMap { recorded.consume(String($0))?.fraction }
        suite.expect(recordedFractions.count == 8 && recordedFractions.first == 0 && recordedFractions.last == 0.99
                     && zip(recordedFractions, recordedFractions.dropFirst()).allSatisfy { $0 <= $1 },
                     "the supplied YouTube URL's captured HLS and audio events produce monotonic whole-job progress")

        var audio = VideoDownloadProgressTracker()
        _ = audio.consume(#"LATTICE_PARTS:"audio""#)
        suite.expect(audio.consume(line("40%", "40", "100", id: "audio"))?.fraction == 0.4,
                     "a single audio stream uses the whole transfer progress range")
        var weighted = VideoDownloadProgressTracker()
        _ = weighted.consume(#"LATTICE_PARTS:[{"format_id":"video","filesize":900},{"format_id":"audio","filesize":100}]"#)
        suite.expect(weighted.consume(line("50%", "450", "900"))?.fraction == 0.45,
                     "known stream sizes weight whole-job progress by their expected bytes")
    }
}
