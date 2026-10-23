# media-optimizer Implementation Plan

**Goal:** Replace the old media workspace with safe local Clop SDK image/GIF and video optimization.

**Architecture:** Use the official pinned MIT ClopSDK as a separately compiled module. Preserve originals by staging copies, validate responses and publish unique outputs. Shared image/OCR/archive helpers move out of the removed media engine. Keep feature identity and island entry points, but expose only Images and Videos.

**Tech Stack:** Swift, SwiftUI, AppKit, existing build.sh and isolated test harness.
---

1. Pin SDK, build its module and record licensing.
2. Test staged-copy validation and output publication; implement serialized SDK service.
3. Replace legacy UI and remove exclusive options/preferences/tests; preserve shared helpers at their true owner.
4. Verify missing Clop, images/GIF/video classification, errors, cancellation, isolation and rendering.
5. Independent review, full tests/developer build; topic commits and push feat/media-optimizer-clop only.

## Status

Baseline branch: refactor/settings-refactor-III at 590fd058. Baseline targeted tests running. Detailed files and red/green results are recorded as each vertical slice is implemented.

