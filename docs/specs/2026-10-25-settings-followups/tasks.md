# Settings Follow-ups Implementation Plan

**Goal:** Resolve the user's screenshot/OCR regressions and settings consistency requests, adding native Magic Mouse music swipes.

**Architecture:** Keep the existing feature/page ownership model and shared native controls. Put behavior fixes in their actual focus, recognition and gesture owners; retain isolated test seams and persisted settings compatibility. Stack all commits on naming PR #16.

**Tech Stack:** Swift, SwiftUI/AppKit, Vision, native NSEvent swipe tracking, generated Swift tests.
---

## Acceptance checklist

- [x] Screenshot mode followed by Escape never raises/flashes an unrelated settings window; trace activation and ownership first.
- [x] General Sound item title Lock Sound; caption Play padlock sound on lock or unlock.
- [x] Radial Menu default-action preview contains no Color Picker entry; preserve real non-UI color functionality.
- [x] Show the menu bar icon has a front icon; icon picker indented and hidden while off.
- [x] Click Dock Tile has Off plus three actions, exactly one selected; Off unloads/uninstalls; verified permission flow retained.
- [x] Dock preview exclusion sheet title Pause in these apps.
- [x] Hide Panel background with Liquid Glass; otherwise shared native tick-free slider, tooltip value, no trailing readout.
- [x] Maximize/full-screen exclusion sheet title Keep full screen in these apps.
- [x] Quit Inactive Apps row and sheet use Don’t quit these apps.
- [x] Half-size cycling label Cycle Left or Right sizes; caption Cycles half, two-thirds, then one-third.
- [x] Margin-edge slider holds row geometry while tracking and disables when margin-maximize shortcut is unset.
- [x] Window Management Actions subtitle uses clearer natural copy.
- [x] OCR stays usable through cold/transient recognition conditions; investigate current silent guards/failed requests; preserve clipboard ownership.
- [x] Audio Output uses native Liquid Glass slider styling where supported.
- [x] Keyboard/Mouse & Trackpad app-exclusion labels use Disable in these apps.
- [x] Bluetooth wake restoration row hidden when first toggle is off.
- [x] Remove Show clipboard activity control from Clipboard History settings.
- [x] Dynamic Island clipboard indicator label Clipboard activity.
- [x] File Cache caption Show drop zone on Dynamic Island while dragging.
- [x] Magic Mouse native swipe progress, native threshold, commit on end, natural scrolling, no momentum/duplicate actions/stuck cues; retain trackpad thresholds.

- [x] Permission label System becomes App Management without changing permission routing.
- [x] Prune unused docs/assets/readme artwork; tracked-reference audit found only lattice-icon.png in use.

## Execution steps

1. Inspect the exact owner files and existing tests. Record focus/OCR root causes and expected behavior. Parent baseline at 08297edd has 103,219 passing checks and a passing Developer build/signature.
2. Implement specified copy/layout changes in settings and localization owners; reuse SettingsValueSlider and AppBundleList.sheetTitle. Run settings/native-control/layout checks affected by changes.
3. Add failing Dock Click selection/availability tests at existing isolated permission and feature-ownership seams; implement Off and deterministic selection; verify denial, off, reselect and unload paths.
4. Add regression tests for capture focus ownership at the existing fake ApplicationFocus/unshown-window boundary, observe failures, make the focused lifecycle fix, rerun capture tests.
5. Add OCR regression coverage using synthetic images and injected recognition outcomes at the existing recognition/completion seams. Fix demonstrated readiness/transient failure handling without sacrificing cancellation, image-generation and pasteboard ownership checks. Verify real synthetic-image recognition separately.
6. Add Magic Mouse lifecycle tests using synthetic phases/native tracking callback values; implement a separate native-swipe path without changing trackpad physical measurement. Verify cancellation, release, momentum, direction, scene changes and haptic boundaries without live playback.
7. Run affected suites serially and build Developer. Render representative settings using disposable identities if needed. Independent source/spec review, resolve valid findings and refresh affected checks.
8. Commit by subfeature, push fix/settings-followups and create/attach its PR with base refactor/lattice-naming. Check CI separately and report pending results accurately. No merge.

## Results

- Implemented all acceptance items. Focus handoff ordering, stale radial actions, Dock Off ownership, native mouse lifecycle, and transient OCR recovery have isolated regression coverage.
- Focused settings, screenshot and notch suites passed: 59,256 checks.
- OCR uses a shared serial engine, synthetic warm-up, fresh CPU-backed requests and bounded retries. Clipboard ownership and editor image-generation guards remain intact.
- Independent source review found no actionable issues.
- Full regression suite passed: 103,266 checks; preference cleanup, uninstall-spaces and Developer installation-isolation checks also passed.
- Developer app build and strict signature verification passed. The build caught the hidden Bluetooth-row modifier and an additional OCR caller; both were corrected and independently reviewed.
- Final affected notch suite passed: 56,482 checks. Isolated native settings rendering and Dock tile activation/denial checks passed (SETTINGS_RENDERING_OK).
- Real Magic Mouse behavior and the user's settings-window flash were not exercised on live hardware. Native callback and focus-ordering contracts were verified with isolated boundaries.
- README reference audit retained lattice-icon.png and removed 24 unused artwork files. Permission display label changed without changing its underlying route.
