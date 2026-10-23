import Foundation

enum VideoDownloadProcessTests {
    static func run(_ suite: TestSuite) {
        do {
            let output = try VideoDownloadProcess().run(executable: "/usr/bin/printf", arguments: ["%s", "literal; $(not-a-command)"],
                environment: [:], timeout: 2)
            suite.expect(String(decoding: output.stdout, as: UTF8.self) == "literal; $(not-a-command)",
                         "subprocess arguments are literal, not shell commands")
        } catch { suite.expect(false, "literal subprocess: \(error)") }
        do {
            let output = try VideoDownloadProcess().run(executable: "/usr/bin/head", arguments: ["-c", "100000", "/dev/zero"],
                environment: [:], timeout: 2)
            suite.expect(output.stdout.count == 100000, "metadata output may be larger than a progress line without being truncated")
        } catch { suite.expect(false, "large metadata response: \(error)") }
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("com.vorssaint.tests.video-process-\(UUID())")
        defer { try? fm.removeItem(at: folder) }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
            let marker = folder.appendingPathComponent("child-survived")
            let process = VideoDownloadProcess()
            let ready = DispatchSemaphore(value: 0), done = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                defer { done.signal() }
                _ = try? process.run(executable: "/bin/sh", arguments: ["-c",
                    "trap 'exit 0' INT; /bin/sh -c 'trap \"\" INT; echo READY; sleep 2; touch \"$1\"' child \"$1\" & wait", "leader", marker.path],
                    environment: ["PATH": "/usr/bin:/bin"], timeout: 8) { line in
                        if line == "READY" { ready.signal() }
                    }
            }
            suite.expect(ready.wait(timeout: .now() + 3) == .success, "owned descendant fixture started")
            process.cancel()
            suite.expect(done.wait(timeout: .now() + 5) == .success, "cancellation finishes after the leader exits")
            RunLoop.main.run(until: Date().addingTimeInterval(2.2))
            suite.expect(!fm.fileExists(atPath: marker.path), "cancellation kills an owned child even after its leader exits")
            let quitMarker = folder.appendingPathComponent("child-survived-quit")
            let quitting = VideoDownloadProcess()
            let quitReady = DispatchSemaphore(value: 0), quitDone = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                defer { quitDone.signal() }
                _ = try? quitting.run(executable: "/bin/sh", arguments: ["-c",
                    "trap 'exit 0' INT; /bin/sh -c 'trap \"\" INT; echo READY; sleep 0.6; touch \"$1\"' child \"$1\" & wait", "leader", quitMarker.path],
                    environment: ["PATH": "/usr/bin:/bin"], timeout: 5) { line in if line == "READY" { quitReady.signal() } }
            }
            suite.expect(quitReady.wait(timeout: .now() + 2) == .success, "shutdown fixture starts")
            quitting.cancel()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            quitting.cancel(immediately: true)
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            suite.expect(!fm.fileExists(atPath: quitMarker.path), "immediate shutdown kills recorded groups after their leader exits, before delayed escalation")
            _ = quitDone.wait(timeout: .now() + 2)
            let leaked = folder.appendingPathComponent("pipe-holder-survived")
            do {
                _ = try VideoDownloadProcess().run(executable: "/bin/sh", arguments: ["-c",
                    "/bin/sh -c 'sleep 4; touch \"$1\"' child \"$1\" & exit 0", "leader", leaked.path],
                    environment: ["PATH": "/usr/bin:/bin"], timeout: 6)
                suite.expect(false, "an exited leader with unclosed descendant output is an observable failure")
            } catch { suite.expect(true, "unclosed descendant output fails rather than hanging") }
            RunLoop.main.run(until: Date().addingTimeInterval(1.2))
            suite.expect(!fm.fileExists(atPath: leaked.path), "output-drain failure terminates its owned descendants before dropping group ownership")
        } catch { suite.expect(false, "isolated cancellation fixture: \(error)") }
    }
}
