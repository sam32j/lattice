import AppKit

enum NotchMusicSwipeEngineTests {
    typealias Contact = NotchMusicSwipeController.Contact

    final class Rig {
        var taps = 0
        var commits: [Bool] = []
        let state = NotchMusicSwipeState(scheduleExpiry: { _, _ in })
        var swipe: NotchMusicSwipeController!

        init(natural: Bool = true) {
            swipe = NotchMusicSwipeController(state: state, onStart: { [unowned self] in taps += 1 },
                onArm: { [unowned self] in taps += 1 },
                naturalScrolling: natural,
                commit: { [unowned self] in commits.append($0); return true })
        }

        func fingers(_ x: Double, y: Double = 0, ids: [Int] = [0, 1], lifted: Bool = false) -> [Contact] {
            ids.enumerated().map { index, id in
                Contact(id: id, position: CGPoint(x: 100 + x, y: 20 + y + Double(index) * 15), lifted: lifted)
            }
        }

        @discardableResult
        func touch(_ x: Double, y: Double = 0, ids: [Int] = [0, 1], t: Double, enabled: Bool = true) -> Bool {
            swipe.touches(fingers(x, y: y, ids: ids), timestamp: t, enabled: enabled, expanded: false)
        }

        @discardableResult
        func lift(t: Double) -> Bool { swipe.touches([], timestamp: t, enabled: true, expanded: false) }

        @discardableResult
        func scroll(_ dx: Double, dy: Double = 0, _ phase: NSEvent.Phase, t: Double,
                    momentum: Bool = false, enabled: Bool = true) -> Bool {
            swipe.scroll(dx: dx, dy: dy, phase: phase, momentum: momentum, precise: true,
                         timestamp: t, enabled: enabled, expanded: false)
        }

    }

    static func run(_ suite: TestSuite) {
        // Fingers drive both stages; the switch waits for the lift.
        var rig = Rig()
        rig.touch(0, t: 0)
        rig.touch(-10, t: 0.02)
        suite.expect(rig.taps == 0, "no stage before a quarter inch of finger travel")
        rig.touch(-18, t: 0.04)
        suite.expect(rig.taps == 1, "the first stage taps at a quarter inch")
        rig.touch(-54, t: 0.06)
        suite.expect(rig.taps == 2 && rig.commits.isEmpty, "arming taps again and switches nothing yet")
        rig.lift(t: 0.08)
        suite.expect(rig.commits == [true], "lifting an armed stroke skips forward, with natural scrolling")

        // Scroll travel alone drives the same stages.
        rig = Rig()
        rig.scroll(0, .began, t: 0)
        rig.scroll(-10, .changed, t: 0.01)
        suite.expect(rig.taps == 0, "scroll travel below the first stage stays silent")
        rig.scroll(-10, .changed, t: 0.02)
        suite.expect(rig.taps == 1, "scroll travel reaches the first stage")
        rig.scroll(-40, .changed, t: 0.03)
        suite.expect(rig.taps == 2 && rig.commits.isEmpty, "scroll travel arms without switching")
        rig.scroll(0, .ended, t: 0.04)
        suite.expect(rig.commits == [true], "a scroll stroke switches when it ends")
        suite.expect(rig.scroll(-30, .init(), t: 0.05, momentum: true), "the coast after a sideways stroke is swallowed")

        // A vertical stroke is never the music's.
        rig = Rig()
        rig.scroll(0, .began, t: 0)
        let vertical = rig.scroll(0, dy: 10, .changed, t: 0.01)
        let after = rig.scroll(-80, .changed, t: 0.02)
        rig.scroll(0, .ended, t: 0.03)
        suite.expect(!vertical && !after && rig.taps == 0 && rig.commits.isEmpty,
                     "a stroke that goes vertical first is left to the island's gestures")
        suite.expect(!rig.scroll(0, dy: -30, .init(), t: 0.04, momentum: true),
                     "the coast after a vertical stroke is not swallowed")

        // Fingers that reach the island just after their scroll take the stroke over.
        rig = Rig()
        rig.scroll(-2, .began, t: 0)
        rig.touch(0, t: 0.03)
        suite.expect(rig.swipe.activeSource == .touch, "fingers arriving within the window take over")
        rig.touch(-54, t: 0.05)
        rig.scroll(-30, .changed, t: 0.05)
        rig.lift(t: 0.07)
        suite.expect(rig.taps == 2 && rig.commits == [true], "a taken-over stroke has both stages and one switch")

        // Late fingers never take over a stroke whose stages already fired.
        rig = Rig()
        rig.scroll(0, .began, t: 0)
        rig.scroll(-25, .changed, t: 0.01)
        rig.touch(0, t: 0.05)
        suite.expect(rig.swipe.activeSource == .scroll, "a stroke that already tapped keeps its source")
        rig.scroll(-40, .changed, t: 0.06)
        rig.scroll(0, .ended, t: 0.07)
        suite.expect(rig.taps == 2 && rig.commits == [true], "the scroll stroke still finishes on its own")

        // A Magic Mouse shows itself with one finger: no trackpad taps.
        rig = Rig()
        rig.touch(0, ids: [0], t: 0)
        rig.scroll(0, .began, t: 0.1)
        rig.scroll(-70, .changed, t: 0.12)
        rig.scroll(0, .ended, t: 0.14)
        suite.expect(rig.taps == 0 && rig.commits == [true], "a mouse swipe switches without trackpad haptics")

        // Holding still never switches: only the lift does.
        rig = Rig()
        rig.touch(0, t: 0)
        rig.touch(-60, t: 0.02)
        suite.expect(rig.commits.isEmpty, "holding an armed stroke still switches nothing")
        rig.scroll(0, .ended, t: 2)
        suite.expect(rig.commits == [true], "the scroll ending at the lift commits a finger stroke")
        rig = Rig()
        rig.touch(0, t: 0)
        rig.touch(-60, t: 0.02)
        rig.touch(0, ids: [7, 8], t: 1)
        suite.expect(rig.commits.isEmpty, "new fingers end a stroke whose lift was lost, without switching")

        // Before the first stage the swipe may turn around; from it on, never.
        rig = Rig()
        rig.touch(0, t: 0)
        rig.touch(10, t: 0.01)
        let firstGuess = rig.state.frame.direction
        rig.touch(-10, t: 0.02)
        suite.expect(firstGuess == .previous && rig.state.frame.direction == .next && rig.taps == 0,
                     "turning around before the first stage changes the direction")
        rig.touch(-20, t: 0.03)
        suite.expect(rig.taps == 1, "the first stage taps and locks the direction")
        rig.touch(5, t: 0.04)
        suite.expect(rig.state.frame.direction == .next && rig.state.frame.progress == 0,
                     "after the first stage, turning around only shrinks the cue")
        rig.touch(200, t: 0.05)
        rig.lift(t: 0.06)
        suite.expect(rig.commits.isEmpty && rig.taps == 1, "no distance the other way can start the other skip")

        // Regret after arming: backing up below the arm point cancels silently.
        rig = Rig()
        rig.touch(0, t: 0)
        rig.touch(-60, t: 0.02)
        suite.expect(rig.taps == 2, "both stages tapped going forward")
        rig.touch(-56, t: 0.03)
        suite.expect(rig.state.frame.progress == 1, "a slight back-off past the arm point stays armed")
        rig.touch(-40, t: 0.04)
        suite.expect(rig.taps == 2 && rig.state.frame.progress < 1, "backing up below it disarms without a tap")
        rig.touch(80, t: 0.05)
        rig.lift(t: 0.06)
        suite.expect(rig.commits.isEmpty && rig.taps == 2,
                     "after regretting, the lift switches nothing and the reverse never fires")
        rig = Rig()
        rig.scroll(0, .began, t: 0)
        rig.scroll(-70, .changed, t: 0.01)
        rig.scroll(30, .changed, t: 0.02)
        rig.scroll(-30, .changed, t: 0.03)
        suite.expect(rig.taps == 3, "arming again going forward taps again")
        rig.scroll(0, .ended, t: 0.04)
        suite.expect(rig.commits == [true], "and the lift then commits")

        // Back-to-back strokes each get both taps and their switch.
        rig = Rig()
        for index in 0..<3 {
            let t = Double(index) * 0.2
            rig.scroll(0, .began, t: t)
            rig.scroll(-70, .changed, t: t + 0.01)
            rig.scroll(0, .ended, t: t + 0.02)
        }
        suite.expect(rig.taps == 6 && rig.commits == [true, true, true], "quick consecutive swipes are all whole")
        rig = Rig()
        for index in 0..<2 {
            let t = Double(index) * 0.15
            rig.touch(0, ids: [index * 2, index * 2 + 1], t: t)
            rig.touch(-60, ids: [index * 2, index * 2 + 1], t: t + 0.03)
            rig.lift(t: t + 0.05)
        }
        suite.expect(rig.taps == 4 && rig.commits == [true, true], "quick consecutive finger swipes are all whole")

        // Without natural scrolling, a leftward finger swipe goes back.
        rig = Rig(natural: false)
        rig.touch(0, t: 0)
        rig.touch(-60, t: 0.02)
        rig.lift(t: 0.04)
        suite.expect(rig.commits == [false], "the direction follows the scrolling preference")
        // The scroll's exact flag sets the direction, never a jittery delta.
        rig = Rig(natural: false)
        rig.touch(0, t: 0)
        rig.touch(-60, t: 0.01)
        _ = rig.swipe.scroll(dx: 5, dy: 0, phase: .changed, momentum: false, precise: true,
                             timestamp: 0.01, enabled: true, expanded: false, inverted: true)
        rig.lift(t: 0.02)
        suite.expect(rig.commits == [false], "a flag arriving mid-stroke never flips that stroke")
        rig.touch(0, ids: [5, 6], t: 0.1)
        rig.touch(-60, ids: [5, 6], t: 0.12)
        _ = rig.swipe.scroll(dx: 3, dy: 0, phase: .changed, momentum: false, precise: true,
                             timestamp: 0.12, enabled: true, expanded: false, inverted: true)
        rig.lift(t: 0.14)
        suite.expect(rig.commits == [false, true], "the next stroke follows the flag")
        for _ in 0..<5 {
            let base = Double(rig.commits.count)
            rig.touch(0, ids: [9, 10], t: base)
            _ = rig.swipe.scroll(dx: 2, dy: 0, phase: .changed, momentum: false, precise: true,
                                 timestamp: base, enabled: true, expanded: false, inverted: true)
            rig.touch(-60, ids: [9, 10], t: base + 0.02)
            _ = rig.swipe.scroll(dx: 4, dy: 0, phase: .ended, momentum: false, precise: true,
                                 timestamp: base + 0.03, enabled: true, expanded: false, inverted: true)
        }
        suite.expect(rig.commits.dropFirst(2).allSatisfy { $0 },
                     "jittery deltas the wrong way never turn later strokes around")

        // Surface changes, disabled input and a third finger end a stroke without a switch.
        rig = Rig()
        rig.swipe.synchronizeSurface("strip")
        rig.touch(0, t: 0)
        rig.touch(-60, t: 0.02)
        rig.swipe.synchronizeSurface("expanded")
        rig.lift(t: 0.04)
        suite.expect(rig.commits.isEmpty, "a different surface cancels the stroke")
        rig = Rig()
        rig.touch(0, t: 0, enabled: false)
        rig.touch(-60, t: 0.02, enabled: false)
        rig.lift(t: 0.04)
        suite.expect(rig.commits.isEmpty && rig.taps == 0, "a disabled surface starts no stroke")
        rig = Rig()
        rig.touch(0, t: 0)
        rig.touch(-30, ids: [0, 1, 2], t: 0.02)
        rig.touch(-60, t: 0.03)
        rig.lift(t: 0.04)
        suite.expect(rig.commits.isEmpty, "a third finger is not a two-finger swipe")

        // Recorded input replays into the same engine.
        rig = Rig()
        replay(sampleRecording, into: rig.swipe)
        suite.expect(rig.commits == [true], "a recorded stroke replays to the switch it made")
    }

    /// Feeds lines in the development recorder's format to a controller.
    static func replay(_ lines: [String], into swipe: NotchMusicSwipeController) {
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let kind = object["k"] as? String, let t = object["t"] as? Double else { continue }
            let enabled = object["en"] as? Bool ?? true, expanded = object["ex"] as? Bool ?? false
            if kind == "t", let raw = object["c"] as? [[Any]] {
                let contacts = raw.compactMap { values -> Contact? in
                    guard values.count == 5, let id = values[0] as? Int, let x = values[1] as? Double,
                          let y = values[2] as? Double else { return nil }
                    return Contact(id: id, position: CGPoint(x: x, y: y),
                                   isResting: values[3] as? Bool ?? false, lifted: values[4] as? Bool ?? false)
                }
                swipe.touches(contacts, timestamp: t, enabled: enabled, expanded: expanded)
            } else if kind == "s" {
                swipe.scroll(dx: object["dx"] as? Double ?? 0, dy: object["dy"] as? Double ?? 0,
                             phase: NSEvent.Phase(rawValue: object["ph"] as? UInt ?? 0),
                             momentum: object["mo"] as? Bool ?? false, precise: object["pr"] as? Bool ?? true,
                             timestamp: t, enabled: enabled, expanded: expanded)
            }
        }
    }

    /// A scroll that began before its fingers reached the island, as the
    /// first stroke after arriving on the strip does.
    static let sampleRecording = [
        #"{"k":"s","t":10.000,"en":true,"ex":false,"dx":0,"dy":0,"ph":32,"mo":false,"pr":true}"#,
        #"{"k":"s","t":10.010,"en":true,"ex":false,"dx":-3,"dy":0,"ph":1,"mo":false,"pr":true}"#,
        #"{"k":"t","t":10.030,"en":true,"ex":false,"c":[[0,120.0,30.0,false,false],[1,121.0,48.0,false,false]]}"#,
        #"{"k":"s","t":10.040,"en":true,"ex":false,"dx":-8,"dy":0,"ph":4,"mo":false,"pr":true}"#,
        #"{"k":"t","t":10.060,"en":true,"ex":false,"c":[[0,95.0,30.5,false,false],[1,96.0,48.0,false,false]]}"#,
        #"{"k":"t","t":10.090,"en":true,"ex":false,"c":[[0,62.0,31.0,false,false],[1,63.0,48.5,false,false]]}"#,
        #"{"k":"s","t":10.100,"en":true,"ex":false,"dx":-20,"dy":0,"ph":4,"mo":false,"pr":true}"#,
        #"{"k":"t","t":10.120,"en":true,"ex":false,"c":[[0,62.0,31.0,false,true],[1,63.0,48.5,false,true]]}"#,
        #"{"k":"s","t":10.130,"en":true,"ex":false,"dx":0,"dy":0,"ph":8,"mo":false,"pr":true}"#,
    ]
}
