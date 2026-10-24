import Foundation

enum VideoDownloaderTests {
    static func run(_ suite: TestSuite) {
        suite.expect((try? VideoDownloadRequest.validatedURL(" https://example.com/watch?v=1&list=2 "))?.host == "example.com",
                     "a pasted HTTP video link is trimmed without interpreting shell syntax")
        for invalid in ["file:///etc/passwd", "javascript:alert(1)", "--exec=bad", "https://user:password@example.com/x", "https://", "https://example.com/\n--exec=bad"] {
            suite.expect((try? VideoDownloadRequest.validatedURL(invalid)) == nil,
                         "non-web, credential-bearing and control-character links are rejected")
        }
        let json = Data(#"{"id":"abc","title":"A video","duration":95,"uploader":"A creator","formats":[{"format_id":"18","ext":"mp4","height":360,"vcodec":"avc1","acodec":"mp4a"},{"format_id":"137","ext":"mp4","height":1080,"vcodec":"avc1","acodec":"none"},{"format_id":"140","ext":"m4a","vcodec":"none","acodec":"mp4a"},{"format_id":"drm","ext":"mp4","height":2160,"vcodec":"avc1","has_drm":true}]}"#.utf8)
        do {
            let info = try VideoDownloadInfo.decode(json)
            suite.expect(info.title == "A video" && info.qualities.map(\.height) == [1080, 360],
                         "quality choices include usable video formats, highest first, excluding DRM and audio-only")
            let args = VideoDownloadRequest.metadataArguments(url: try VideoDownloadRequest.validatedURL("https://example.com/$(touch%20bad)"))
            suite.expect(args.suffix(2).first == "--" && args.last == "https://example.com/$(touch%20bad)",
                         "URL remains a literal final argument after the option terminator")
        } catch { suite.expect(false, "valid single-video metadata decodes: \(error)") }
        for data in [Data("{}".utf8), Data(#"{"_type":"playlist","entries":[]}"#.utf8)] {
            suite.expect((try? VideoDownloadInfo.decode(data)) == nil, "empty and playlist results are not downloadable single videos")
        }
        suite.expect(VideoDownloadRequest.hasPlayableVideo(Data(#"{"streams":[{"codec_type":"video","width":1280,"height":720}],"format":{"duration":"10.5"}}"#.utf8)),
                     "a probed video stream with dimensions and duration can be published")
        suite.expect(!VideoDownloadRequest.hasPlayableVideo(Data(#"{"streams":[{"codec_type":"audio"}],"format":{"duration":"10"}}"#.utf8)),
                     "an audio-only result cannot claim successful video download")
        let absent = VideoDownloadDependencies.discover(environment: ["PATH": "relative/bin"], executable: { _ in false })
        suite.expect(!absent.ready && absent.brew == nil && absent.installArguments == ["install", "yt-dlp", "ffmpeg", "deno"],
                     "a machine without dependencies gets a concrete installation plan including ffprobe via ffmpeg")
        let onlyProbeMissing = VideoDownloadDependencies(tools: ["yt-dlp": "/tools/yt-dlp", "ffmpeg": "/tools/ffmpeg", "deno": "/tools/deno"], environment: [:])
        suite.expect(onlyProbeMissing.installArguments == ["install", "ffmpeg"], "a missing ffprobe is repaired by installing its owning formula")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("com.vorssaint.tests.download-containment-\(UUID())")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let empty = folder.appendingPathComponent("empty.mp4")
            try Data().write(to: empty)
            suite.expect((try? VideoDownloadRequest.validatedOutput(empty, from: folder)) == nil,
                         "empty results are rejected before ffprobe")
            suite.expect((try? VideoDownloadRequest.validatedOutput(URL(fileURLWithPath: "/etc/hosts"), from: folder)) == nil,
                         "reported paths outside owned staging cannot be probed or published")
            let audioArgs = VideoDownloadRequest.downloadArguments(url: try VideoDownloadRequest.validatedURL("https://example.com/v"),
                                                                  quality: .audio, staging: folder, ffmpeg: "/tools/ffmpeg")
            suite.expect(audioArgs.contains("--extract-audio") && audioArgs.contains("m4a"),
                         "audio quality requests audio stream extraction to m4a format")
            let parsedProgress = VideoDownloadRequest.parseProgress("LATTICE_PROGRESS:42%|612000000|1400000000|8400000|60")
            suite.expect(parsedProgress?.fraction == 0.42 && parsedProgress?.downloadedBytes == 612000000 && parsedProgress?.totalBytes == 1400000000,
                         "detailed progress line parses fraction, bytes, and rate")
            suite.expect(VideoDownloadRequest.hasPlayableMedia(Data(#"{"streams":[{"codec_type":"audio"}],"format":{"duration":"10"}}"#.utf8), isAudio: true),
                         "audio extraction verifies playable audio duration and stream")
            let history = DownloadHistoryStore(storeURL: folder.appendingPathComponent("history.json"))
            let sampleFile = folder.appendingPathComponent("sample.mp4")
            try Data("sample".utf8).write(to: sampleFile)
            history.record(fileURL: sampleFile, title: "Sample Video", qualityTag: "1080p")
            suite.expect(history.items.first?.title == "Sample Video" && history.items.first?.qualityTag == "1080p",
                         "recent downloads store records file, title and quality")
            history.clear()
            suite.expect(history.items.isEmpty, "history store clear removes records")
        } catch { suite.expect(false, "contained publication validation: \(error)") }
        VideoDownloadProcessTests.run(suite)
        VideoDownloaderServiceTests.run(suite)
    }
}
