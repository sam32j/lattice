# Settings Follow-ups Implementation Plan

**Goal:** Resolve the user's screenshot/OCR regressions and settings consistency requests, adding native Magic Mouse music swipes.

**Architecture:** Keep the existing feature/page ownership model and shared native controls. Put behavior fixes in their actual focus, recognition and gesture owners; retain isolated test seams and persisted settings compatibility. Stack all commits on naming PR #16.

**Tech Stack:** Swift, SwiftUI/AppKit, Vision, native NSEvent swipe tracking, generated Swift tests.
---

## Acceptance checklist

- [ ] Screenshot mode followed by Escape never raises/flashes an unrelated settings window; trace activation and ownership first.
- [ ] General Sound item title Lock Sound; caption Play padlock sound on lock or unlock.
- [ ] Radial Menu default-action preview contains no Color Picker entry; preserve real non-UI color functionality.
- [ ] Show the menu bar icon has a front icon; icon picker indented and hidden while off.
- [ ] Click Dock Tile has Off plus three actions, exactly one selected; Off unloads/uninstalls; verified permission flow retained.
- [ ] Dock preview exclusion sheet title Pause in these apps.
- [ ] Hide Panel background with Liquid Glass; otherwise shared native tick-free slider, tooltip value, no trailing readout.
- [ ] Maximize/full-screen exclusion sheet title Keep full screen in these apps.
- [ ] Quit Inactive Apps row and sheet use Don’t quit these apps.
- [ ] Half-size cycling label Cycle Left or Right sizes; caption Cycles half, two-thirds, then one-third.
- [ ] Margin-edge slider holds row geometry while tracking and disables when margin-maximize shortcut is unset.
- [ ] Window Management Actions subtitle uses clearer natural copy.
- [ ] OCR stays usable through cold/transient recognition conditions; investigate current silent guards/failed requests; preserve clipboard ownership.
- [ ] Audio Output uses native Liquid Glass slider styling where supported.
- [ ] Keyboard/Mouse & Trackpad app-exclusion labels use Disable in these apps.
- [ ] Bluetooth wake restoration row hidden when first toggle is off.
- [ ] Remove Show clipboard activity control from Clipboard History settings.
- [ ] Dynamic Island clipboard indicator label Clipboard activity.
- [ ] File Cache caption Show drop zone on Dynamic Island while dragging.
- [ ] Magic Mouse native swipe progress, native threshold, commit on end, natural scrolling, no momentum/duplicate actions/stuck cues; retain trackpad thresholds.

- [ ] Permission label System becomes App Management without changing permission routing.
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

Status: naming PR published; fix worktree clean at parent before these docs. Magic Mouse design approved. Investigation underway; no feature code changed yet.
