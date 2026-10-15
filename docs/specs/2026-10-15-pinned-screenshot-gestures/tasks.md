# Pinned Screenshot Gestures Implementation Plan

**Goal:** Zoom pinned screenshots with scrolling or pinching and change their opacity with Option + scrolling.

**Architecture:** A small AppKit view superclass handles native gesture events for the existing pinned screenshot content view. Gestures update the containing window directly; existing context menu, drag, resize and click-through behavior remain available. No settings or dependencies are added.

**Tech Stack:** Swift, AppKit, existing standalone Swift test runner.
---

## Approved behavior and test seams

- Wheel scrolling zooms around the pointer in 3% steps; precise scrolling uses a smaller continuous gain.
- Option + scrolling changes opacity, clamped to 20–100%.
- Pinching zooms around the pointer with the screenshot's aspect ratio preserved.
- Zoom stays within the pointer's display and the pin's existing minimum size.
- Momentum and invalid gesture values do not change the pin. Click-through pins ignore gestures.
- Test native `scrollWheel(with:)` and `magnify(with:)` entry points on a real, hidden AppKit window using controlled native events. Assert window frame and opacity, rather than private implementation text.
- Push `feat/pinned-screenshot-gestures` to `sam32j/vorssaint-utils`; keep the feature branch for review.

## Tasks and evidence

- [x] Establish baseline: existing screenshot suite at `794608a58d8a88608d3c3cb2e4f22373cf52bfdc`; no pre-existing working changes. All 1,155 screenshot checks passed.
- [x] Add `Tests/ScreenshotPinGestureTests.swift` to the test runner and an initially empty `ScreenshotPinGestureView`. The first native wheel test failed with width 200 instead of 206.
- [x] Implement wheel zoom in `Sources/Vorssaint/Services/QuickTools/ScreenshotPinGestureView.swift`; use it as the superclass of the existing pin content view. Native wheel test passed.
- [x] Add and fail an Option-scroll test; implement bounded opacity changes. Observed opacity 0.7 instead of 0.75 and unwanted zoom before the handler; both passed afterward.
- [x] Add and fail a pinch test; implement pointer-anchored pinch zoom. Observed unchanged width/height/anchor before the handler; all passed afterward.
- [x] Cover precise scrolling, direction, no momentum, minimum/maximum size, display edges, invalid input, detached views, and click-through pins with further red/green slices. All 39 native gesture checks passed before the additional review regression.
- [x] Run the gesture suite, full existing test suite, optimized app build, bundled app self-test and strict signature verification. Gesture and screenshot suites passed; the full run has only the 15 failures reproduced on untouched upstream.
- [x] Obtain independent review, address actionable findings, and refresh affected checks. Reviewer verdict: ready; no remaining actionable findings after aspect-ratio correction.
- [x] Commit task files without a co-author trailer, push the feature branch, and report the built app and verification limits. Authorized outcome: preserve and push the feature branch; no upstream PR or merge.

## Files

- Add: `Sources/Vorssaint/Services/QuickTools/ScreenshotPinGestureView.swift`.
- Modify: `Sources/Vorssaint/Services/QuickTools/ScreenshotPinController.swift` (content-view superclass and gesture documentation).
- Add: `Tests/ScreenshotPinGestureTests.swift`.
- Modify: `Tests/MetricsTests.swift` (selectable suite).
- Modify: `build.sh` (compile the gesture view into the test executable).
- Add: this task record.

## Verification commands

```sh
./build.sh --test-suite=screenshots
./build.sh --test-suite=screenshot-pins
./build.sh --test
./build.sh
./build/stage/Vorssaint.app/Contents/MacOS/Vorssaint --selftest
codesign --verify --deep --strict build/stage/Vorssaint.app
git diff --check
```

Expected: no gesture or screenshot regressions, app build without warnings, `SELFTEST OK`, and a valid signature. Controlled native events do not establish physical trackpad, mouse or multiple-display interaction; report those limits unless tested directly.

## Review and next action

- Native boundary testing caught a fractional overflow that AppKit rounded into a window one point wider than the screen. Clamping the computed dimensions to the actual display fixed it; the native boundary tests passed.
- Independent read-only review identified aspect-ratio drift from repeatedly scaling native rounded frames. The 60-event native regression reproduced a ratio of 1.625 instead of 2. Zoom now derives height from the image's stable `contentAspectRatio`; all 40 native gesture checks passed. Focused re-review found no remaining actionable issues.
- macOS 27.2 (26B5101f), Apple M2 MacBook Air (Mac14,2), 16 GB. Optimized Apple Silicon app build completed without compiler warnings; fan helper self-test passed, bundled app reported `SELFTEST OK`, and strict deep signature verification passed. Signature is ad hoc for local use. App was not installed or launched as an interactive utility.
- Full tests on the feature source initially reported 15 migration/default failures out of 116,408 checks. An untouched archive of baseline `794608a58d8a88608d3c3cb2e4f22373cf52bfdc` reproduced the exact same 15 failures out of 116,368 checks. All failing file/line/message entries matched byte for byte. Preference cleanup, uninstall-spaces and developer-install-isolation checks passed in both runs.
- Final reviewed source: 116,409 checks, with all 40 native gesture checks and 1,155 existing screenshot checks passing. The full run has precisely the same 15 failures as untouched upstream; no additional failures. Preference cleanup, uninstall-spaces and developer-install-isolation checks passed. The full suite is not green on this Mac; the unrelated existing failures were not changed as part of this feature.
- The staged app is now named `build/stage/Vorssaint Beta.app`; the existing name was preserved and its strict deep signature re-verified. This is a folder name only; no application identity or branding changes are included in the source diff.
- Physical mouse/trackpad operation, multiple displays, manual edge resizing and interaction with the user's everyday utility remain untested. Native tests cover the inherited view handlers and real window geometry; app build and self-test cover compilation and basic runtime health.
