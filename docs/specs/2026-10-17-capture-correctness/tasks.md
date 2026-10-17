# Capture Correctness Implementation Plan

**Goal:** Fix the five reviewed recording and screenshot-editor defects without unrelated refactoring.

**Architecture:** Serialize recording import and index persistence through the history queue. Track confirmed original preservation, exported document snapshots, the recorder waiting state, and current native text-editor bindings explicitly.

**Tech Stack:** Swift, AppKit, SwiftUI, Foundation, the existing generated-source regression harness.
---

The user approved focused edits in existing oversized files and regression tests at storage, recorder start/close/export, and text-editor update boundaries. Preserve all pre-existing edits. Keep new handwritten files below 300 lines. Leave work uncommitted on the current feature branch.

## Baseline

- HEAD: `4246fe2bdba3a83d48c2946fa3edf6bcef0a74a9`.
- Existing cleanup and user tests are preserved in `/private/tmp/lattice-before-quality-fixes.patch`.
- Previous affected regression run: 2,992 checks passed, followed by 98 final pin checks, release build, selftest, and signature verification.

## Tasks and acceptance

### 1. Transactional history import

Files: `RecentCaptureStore.swift`, `RecentCaptureService.swift`, new `Tests/RecordingImportTests.swift`, test runner and source list.

1. Add a failing regression that imports a recording before its first index, reloads/persists history, and reads the retained entry and bytes.
2. Add a queue-confined `importRecording(from:entry:)` operation: load first, copy with private permissions, commit its entry, and roll back file and in-memory entries on persistence failure.
3. Call it on the history queue, report a confirmed URL asynchronously, and generate thumbnails only after commit.
4. Verify concurrent cleanup, copy/index failures, retries, and unchanged source bytes through real temporary files.

### 2. Safe editor closing

Files: `ScreenRecorderService.swift`, `RecorderEditorController.swift`, new `Tests/RecorderCloseSafetyTests.swift`, generated test fixtures.

1. Exercise the production close/discard decisions with a failed, successful, and subsequently removed backup.
2. Pass the confirmed backup URL into the editor. Require confirmation when neither an original nor an export is preserved; retain explicit confirmed-discard behavior.
3. Reuse localized discard messages and keep the take alive until preservation completes.
4. Verify closing and cancellation never silently delete an unpreserved take.

### 3. Export snapshot saved state

Files: `RecorderEditorController.swift`, new `Tests/RecorderSaveStateTests.swift`, generated test fixtures.

1. Exercise production export completion with an encoder reply held while the document changes; expect the later edits to remain modified.
2. Mark only the captured export document saved on successful completion. Remove the controller's current-document mark.
3. Verify successful unchanged export, changed-during-export, failure, and cancellation cases.

### 4. Native annotation editor updates

Files: `ScreenshotEditorView.swift`, new `Tests/ScreenshotTextEditorTests.swift`, generated test fixtures.

1. Host the production representable, replace its binding/callback/wrapping inputs, and exercise its actual NSTextView.
2. Refresh coordinator parent, callback, wrapping mode, and container width during updates without resetting unchanged text or selection.
3. Verify commits target the new annotation and edits reach the new binding.

### 5. Delayed recorder lifecycle

Files: `ScreenRecorderService.swift`, `Tests/RecorderPreparationTests.swift`, generated test fixtures.

1. Exercise production record admission in delayed mode; expect it to reserve capture and reject a second selection.
2. Add explicit waiting state, clear it on start/cancel, and guard delayed callbacks with their original generation.
3. Verify Stop and toggle cancellation release the indicator, stale starts are ignored, and immediate preparation still works.

## Verification and review

- For each task, run its regression before implementation and retain the expected failure evidence, then verify the fixed case.
- Run `./build.sh --test-suite=storage --test-suite=recording --test-suite=recorder --test-suite=screenshots --test-suite=capture-requirements` plus affected repository checks.
- Request independent review of all task changes, address substantiated findings, and rerun affected checks.
- Build with `./build.sh`, run `./build/Lattice --selftest`, verify the bundle with `codesign --verify --deep --strict build/stage/Lattice.app`, and run `git diff --check`.
- Report actual evidence and any manual UI limitations. Do not commit, publish, install, or merge without user authorization.

## Execution record

- [x] Transactional import: initial regression failed because the import operation did not exist; the implemented store and asynchronous stash regressions pass with real temporary files. Added collision, index failure/rollback/retry, private permissions, and symlink rejection coverage. The symlink regression reproduced the escape before the destination-parent check was added.
- [x] Close safety: production close/discard regressions initially failed for unpreserved recordings and cleared history. Preservation checks now refresh cached URL metadata and verify both original and successful exported/copied output paths. Removing the only export also reproduced the old unsafe decision before correction.
- [x] Export snapshot: holding the encoder while changing the document reproduced the incorrect saved state; actual model/controller completion methods now mark only the submitted snapshot saved. Success, later edits, undo to saved state, failure, and cancellation pass.
- [x] Native text editing: hosted NSTextView regressions initially failed for stale binding, callback, and wrapping. Current-input updates now pass, including bounded resizing and selection preservation.
- [x] Delayed lifecycle: actual recorder methods initially failed five admission/cancellation/stale-start checks. Waiting state and original-generation checks now pass, including immediate countdown compatibility.
- [x] Independent review: one actionable import symlink-boundary finding was fixed and re-reviewed. Final verdict: no remaining blockers in the five fixes. Alert presentation, media encoder internals, and recording surfaces are substituted in tests; real desktop capture and manual UI interaction were not exercised.
- [x] Final affected suites passed 2,822 checks: overlays, screenshot-pins, screenshots, recorder, capture, storage, recording, and capture-requirements. Log: `/private/tmp/lattice-fixes-final-tests.log`.
- [x] Final optimized app build passed without compiler warnings/errors. Log: `/private/tmp/lattice-fixes-final-build.log`.
- [x] Final app reported `SELFTEST OK`; strict deep signature verification and `git diff --check` passed. Changes remain uncommitted on `feat/direct-capture-storage`; no installation or publishing was performed.

Concurrent changes appeared in `ScreenshotPinWindow.swift`, `Tests/ScreenshotPinChromeTests.swift`, and `Tests/ScreenshotPinWindowTests.swift` during this task. They were preserved, excluded from this task's review, and included in the final build/test state.
