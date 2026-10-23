# media-optimizer Implementation Plan

**Goal:** Replace the old media workspace with standalone images/GIFs and native macOS video compression.

**Architecture:** Remove Clop SDK and build image tools from pinned source. Use ImageIO and AVFoundation for native formats, staging and validating every output, never overwriting originals. Retain the focused two-category UI and shared-helper ownership cleanup.

**Tech Stack:** Swift, SwiftUI, AppKit, existing build.sh and isolated test harness.
---

1. Replace SDK build integration with pinned PNG/GIF tools, corresponding source, licenses and nested signing.
2. Add failing actual-file compression tests at the approved optimizer boundary, then implement native ImageIO/AVFoundation adapters and cancellable tools.
3. Adapt batch service for per-job cancellation, smaller-output selection, safe publication and completed-file retention.
4. Remove old UI/options/preferences and Clop copy, retain shared helpers; render image/video layouts.
5. Run focused and full tests, developer build/signature/selftest and independent review; topic commits and push feat/media-optimizer only.

## Status

Complete. Baseline: refactor/settings-refactor-III at 590fd058. Final branch: feat/media-optimizer. The unpublished SDK prototype commit was removed before publication; no Clop source or dependency remains in the published feature history.

- RED: native image encoder boundary initially absent. GREEN: actual JPEG/PNG/HEIC/GIF fixtures and native HEVC video exports. Service tests cover contained staging, original preservation, no-size-reduction copies, errors, collisions and partial-batch cancellation.
- Final focused media suite: 32 checks, including JPEG size reduction, animated GIF frames, source preservation, corrupt video and missing bundled helper failures, 1920x1080 portrait video with audio, native 1080p/720p output caps, duration, and in-flight cancellation.
- Final `./build.sh --test`: 102274 checks passed, plus preference cleanup, uninstall-spaces and developer-install-isolation shell checks. Removed tests exercised retired converter/OCR UI, not retained shared functionality.
- `./build.sh --dev`, `swift package describe`, shell syntax and strict deep signature verification passed. No Clop SDK module or separate app is needed.
- Isolated bundle rendered Images, Videos and an actual bundled-encoder PNG result: `SETTINGS_RENDERING_OK`; visually inspected. Isolated `--selftest`: `SELFTEST OK`.
- Motion probe initially reproduced a fixture startup issue: intrinsic measurement arrived before the fixture owned its new window. Replaying the measured size after attachment fixed it without changing production window code. Re-run: `MEDIA MOTION OK`.
- Independent source review: ready, no remaining blockers. Reviewer did not independently execute encoders or builds. Native deprecation warnings remain for APIs still supported by the macOS 14 deployment target.
- Packaging: checksum-pinned source archives and license texts accompany source-built helpers. Executables total about 580 KB after signing; source/licenses about 1.9 MB. No real user files, permissions, hardware state or installed applications were modified by tests.
- Rebuilt both helpers successfully from a writable copy of the app's bundled MediaTools source directory, verifying the distributed build recipe without Homebrew library dependencies.
- Limitations: native input codec support, HEVC output, fixed 1080p/720p caps, no animated PNG/HEIF or oversized images. Compression may be lossy; it is not metadata sanitization. MKV/WebM are not guaranteed inputs. FFmpeg remains a separate downloader dependency, not an optimizer dependency.
