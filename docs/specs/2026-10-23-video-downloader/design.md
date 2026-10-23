# video-downloader MVP

User delegated design and plan approval while unavailable. No approval dialogs are required.

## Goal

Add a local single-video downloader with metadata, quality, destination and guided dependencies.

## Design

A page-owned SwiftUI utility runs argument-array yt-dlp processes without a shell. Discover yt-dlp, ffmpeg, ffprobe and a supported JS runtime in Homebrew/PATH. Explicit Brew install, official Homebrew setup if absent. Separate bounded metadata decoding, isolated staging, progress and cancellation. Never auto-read cookies, overwrite files or execute a URL as a command.

## Alternatives

Prefer the requested local integration over a cloud service, which adds uploads and credentials. Prefer a focused MVP over retaining the old multi-tool/editor surface. Dependencies are not installed on the developer's Mac by verification. The app requires explicit user action for installation or launching Clop.

## Verification seams

Selected under delegated discretion: actual command/request construction, decoding and filesystem publication; subprocess fixtures for timeout/cancellation/errors; isolated service state; existing settings navigation tests and developer-only rendering. No real downloads, installs, credentials or user files during tests. Report real engine/site limitations separately.

## Acceptance

Usable consistent card-based utility, visible prerequisite status, actionable errors, cancellation, no original-file changes, no silent failure. Local execution is not a promise that a video site will permit download. Only download content the user is authorized to save.

