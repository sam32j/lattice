# video-downloader Implementation Plan

**Goal:** Add a local single-video downloader with metadata, quality, destination and guided dependencies.

**Architecture:** A page-owned SwiftUI utility runs argument-array yt-dlp processes without a shell. Discover yt-dlp, ffmpeg, ffprobe and a supported JS runtime in Homebrew/PATH. Explicit Brew install, official Homebrew setup if absent. Separate bounded metadata decoding, isolated staging, progress and cancellation. Never auto-read cookies, overwrite files or execute a URL as a command.

**Tech Stack:** Swift, SwiftUI, AppKit, existing build.sh and isolated test harness.
---

1. Test HTTP URL validation, metadata/quality selection and command argument boundaries.
2. Implement cancellable subprocess transport and dependency discovery/install with bounded logs.
3. Implement fetch/download state, stale result protection, safe output publication and destination choice.
4. Add always-visible Utilities entry and intuitive cards for setup, link, details and result.
5. Test isolated executables and fixtures, render UI, developer build/full tests, independent review.
6. Commit subfeatures and push feat/video-downloader only.

## Status

Baseline branch: refactor/settings-refactor-III at 590fd058. Baseline targeted tests running. Detailed files and red/green results are recorded as each vertical slice is implemented.

