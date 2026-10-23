# media-optimizer MVP

User delegated design and plan approval while unavailable. No approval dialogs are required.

## Goal

Replace the old media workspace with standalone local image/GIF optimization and native macOS video compression.

## Design

User approved the native-video pivot on 2026-10-23 after comparing native and bundled FFmpeg. Remove ClopSDK and all Clop.app requirements. Use AVFoundation export for video, ImageIO for JPEG/HEIC, and bundled source-built pngquant/gifsicle for PNG/GIF. GIF remains in Images. Preserve originals by staging copies, validate outputs and publish unique files. When encoding is not smaller, publish the unchanged staged copy and report it as already optimized. Shared image/OCR/archive helpers live outside the removed media engine. Keep feature identity and island entry points, but expose only Images and Videos.

Videos export as MP4 using Apple's HEVC presets (up to 1080p normally, 720p for stronger compression). Explain this in the UI, preserve audio and orientation, validate playable output and duration, and fail unsupported inputs explicitly. Native is not a universal MKV/WebM decoder. No Clop, FFmpeg or Homebrew is needed by Media Optimizer. Tiny image executables are compiled from checked-in, hash-pinned upstream source, link only system libraries, and are signed before the enclosing app. Include licenses and full corresponding source archives in the bundle.

## Alternatives

Native video keeps the app lightweight and handles everyday phone videos and screen recordings. Bundled FFmpeg would broaden container/codec support and software quality controls at a much larger size. Clop SDK requires a separate application and was rejected by the user. No cloud uploads or dependency installation occur in optimizer verification.

## Verification seams

Selected under delegated discretion: actual command/request construction, decoding and filesystem publication; subprocess fixtures for timeout/cancellation/errors; isolated service state; existing settings navigation tests and developer-only rendering. No real downloads, installs, credentials or user files during tests. Report real engine/site limitations separately.

## Acceptance

Usable consistent card-based utility, no separate app prerequisite, actionable errors, cancellation, no original-file changes, no silent failure. Video Downloader is a separate branch and utility with separate dependencies.
