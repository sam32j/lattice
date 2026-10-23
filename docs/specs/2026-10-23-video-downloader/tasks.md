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

Complete. Baseline: refactor/settings-refactor-III at 590fd058.

- URL, quality, dependency discovery, metadata/probe and containment checks pass.
- Local executable fixtures cover real process launch, encoded argument safety, progress, download publication, collisions, cancellation, shutdown and pipe-holding descendants. No network download or package installation was performed.
- RED reproduced orphaned descendants after leader exit; GREEN after terminating the recorded process group before dropping ownership. Final full `./build.sh --test`: 102621 checks passed, plus preference cleanup, uninstall-spaces and developer-install-isolation checks.
- Final `./build.sh --dev` passed; `codesign --verify --deep --strict` passed.
- Isolated test bundle rendered setup/details using local protocol fixtures, visually inspected; `SETTINGS_RENDERING_OK`. Isolated `--selftest`: `SELFTEST OK`.
- Independent source review: ready, no remaining actionable findings. Review did not independently execute tests or contact video sites.
- Runtime limitation: real site compatibility depends on yt-dlp/site behavior. Browser credentials, playlists/live streams and DRM bypass are intentionally unsupported. Actual Homebrew installation was not exercised against the user's machine.

