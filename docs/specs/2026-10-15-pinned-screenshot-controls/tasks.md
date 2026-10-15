# Pinned Screenshot Controls Implementation Plan

**Goal:** Add the approved CleanShot-inspired controls, feedback, rounded-corner setting and native file drag to pins in Samuel's fork.

**Architecture:** Keep the existing image panel and gesture geometry. Extract focused AppKit pin modules, use small child panels for independent interaction and opacity, and journal no private image content except an on-demand file promise export.

**Tech Stack:** Swift, AppKit, Core Animation, SwiftUI preferences, existing native test runner.
---

## Baseline

- Base revision: ea225d279fd138bdaa50a3f0cce6e79b2a7d9e48.
- Branch: feat/pinned-screenshot-controls; clean new worktree, no user edits.
- Existing screenshot-pins baseline: 40 checks passed before implementation.

## Tasks

1. [x] Preserve existing gesture tests; add a failing opacity-floor test, run `zsh build.sh --test-suite=screenshot-pins`, implement 10% floor, rerun. Extract pin window/content into focused files (maximum 300 handwritten lines each) with action callbacks to preserve copy/save/close behavior.
2. [x] Add a failing locked-gesture test on a real panel; implement a lock gate and native window controls. Verify size/movement disabled, opacity still works, unlock restores interactions.
3. [x] Exercise feedback takeover and timeout through the real feedback view. Implement a single opaque pill, cancellation/reset, original-point-size multiplier and image-only opacity. Verify late events after close are safe.
4. [x] Test click-through hover opacity and controls using real panels; implement independent child surfaces and lifecycle-bound hover monitoring. Verify base opacity restoration, independent lock and close cleanup.
5. [x] Add and run file promise output/drop-result tests; implement on-demand full-resolution PNG export and retain provider through completion. Verify cancel/Option-drop keeps pin, success closes, errors remain observable.
6. [x] Add the rounded preference and localized setting, update live pins, and verify backup coverage. Treat Defaults registry as declarative configuration; place new localized strings in a focused catalog and settings in a new view.
7. [x] Check approved spec against the full diff. Request independent review as required by implement skill, resolve findings and re-review material fixes.
8. [x] Run final screenshot-pins, screenshot/settings/backup regressions, optimized app build, selftest, signature verification and native UI inspection. Record physical-device/multi-display gaps honestly.
9. [x] Commit task-owned changes, push the feature branch to the fork under prior feature-branch authorization. Keep prior upstream PR focused; do not publish a new upstream PR without authorization.

## Evidence and review

Update this section as each task completes. Never replace a baseline failure with a passing claim. Existing full-suite baseline has 15 unrelated failures; prefer affected suites and compare any new failures to the clean base.

## Final evidence

- Final focused suites: **9,708 checks passed**: pins 77, screenshots 1,155, settings 494, preferences 111, localization 7,871.
- Full optimized application build passed without compiler warnings. App selftest returned SELFTEST OK; deep strict code-signature verification passed. Build is locally ad-hoc signed, not an official notarized release.
- Native attached-window checks verify four child surfaces, independent image opacity, click-through toggle via actual NSButton actions, lock, child tracking and cleanup. A PNG provider survives closed pin deallocation, preserves 400×200 original pixels, refuses destination collisions and reports write failures.
- Independent Code Reviewer verdict: ready, no actionable findings after final additions.
- macOS 27.2 (26B5101f), Apple Silicon. CUA opened the generated-artwork native preview and inspected the image/corners; its selected-window capture excluded child control surfaces. Physical trackpad input, actual cross-app file dragging and multiple displays/Spaces remain unverified. Do not describe native synthetic events as physical-device testing.
- Test-only interactive fixture: build/metrics-tests --pin-preview. It uses generated artwork, an underlying button and a real NSFilePromiseReceiver writing only to a disposable temporary folder.
- Existing upstream PR 3107 remains unchanged; feature branch is the delivery target for this expanded scope.
