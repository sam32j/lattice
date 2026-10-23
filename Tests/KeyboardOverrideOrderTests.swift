import Foundation

enum KeyboardOverrideOrderTests {
    static func run(_ suite: TestSuite) {
        var raw = "8:25,0:50"
        suite.expect(KeyboardDebounceOverrides.decode(raw).map(\.keyCode) == [8, 0],
                     "existing per-key entries retain their stored order, not alphabetical or key-code order")
        raw = KeyboardDebounceOverrides.setting(75, for: 8, in: raw)
        suite.expect(raw == "8:75,0:50", "editing a per-key interval keeps its position")
        raw = KeyboardDebounceOverrides.setting(30, for: 12, in: raw)
        suite.expect(raw == "8:75,0:50,12:30", "new per-key entries append at the bottom")
        raw = KeyboardDebounceOverrides.removing(0, from: raw)
        raw = KeyboardDebounceOverrides.setting(50, for: 0, in: raw)
        suite.expect(KeyboardDebounceOverrides.decode(raw).map(\.keyCode) == [8, 12, 0],
                     "removing and re-adding puts the key last, including after reload")
        suite.expect(KeyboardDebounceOverrides.decode("bad,8:25,0:50,8:75").map(\.keyCode) == [8, 0],
                     "malformed entries are ignored and repeated keys do not create duplicate rows")
    }
}
