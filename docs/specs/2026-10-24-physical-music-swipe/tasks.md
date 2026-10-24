# Physical Music Swipe Implementation Plan

**Goal:** Enforce a real ¾-inch music swipe and provide progressive compact/expanded feedback without changing the requested natural-scrolling mapping.

**Architecture:** A pure physical-contact recognizer combines measured touch travel with preference-adjusted horizontal scroll direction. A native adapter owns event ordering, cancellation and the existing playback command boundary; a small observable feedback model drives isolated SwiftUI overlays. The existing general scroll recognizer retains vertical behavior only.

**Tech Stack:** Swift, AppKit NSTouch/NSEvent, SwiftUI, existing generated regression/native rendering harness.
---

### Task 1: Physical recognition

Create `Sources/Vorssaint/Services/Notch/NotchMusicTrackSwipe.swift` and `Tests/NotchMusicTrackSwipeTests.swift`. Register the test source through existing build/test discovery and invoke from `Tests/NotchGestureTests.swift`.

1. Write a synthetic two-contact test: 53.99 physical points does not fire, 54 does, a held stroke never fires twice.
2. Run `./build.sh --test-suite=notch` and observe RED.
3. Implement physical threshold/progress with finite coordinates, identity checks and direct raw horizontal direction.
4. Add one regression at a time for event ordering, unequal travel, vertical/diagonal motion, extra/replaced fingers, cancellation/disable and missing physical data. Run focused checks after each coherent correction.

### Task 2: Input ownership and lifecycle

Create small native/controller/feedback modules under `Services/Notch`. Thin adapters in `NotchService.swift` provide current eligibility and reset on teardown. Generalize the existing native touch callback in `NotchWindowHost.swift` while preserving capture routing.

1. Test order-independent physical/scroll input and denied command completion with injected playback callbacks, never live playback.
2. Implement the coordinator and finite-lived feedback state.
3. Remove unused horizontal direction/threshold logic from `NotchGestureSupport.swift`; keep existing vertical/capture contracts green. Migrate horizontal tests to the actual physical-input seam, retaining the four natural-scrolling cases.

### Task 3: Progressive music presentation

Create `UI/Notch/NotchMusicSwipeFeedback.swift`. Modify `NotchMusicStrip.swift` for visualizer crossfade/scale. Extract the transport component from oversized `NotchMusicView.swift` into a focused file before adding its circle feedback, and remove the expanded whole-player nudge.

1. Verify progress 0, partial, complete and cancelled states at the presentation-model boundary.
2. Render compact and expanded overlays with previous/next directions and Reduce Motion using isolated fixtures.
3. Confirm neutral contrast, stable bounds/hit targets, existing compact nudge only after accepted commands, and no expanded position shift.

### Task 4: Review and finish

Run affected vertical/capture/music/native input suites, full regressions, developer build, strict signature verification, isolated selftest/rendering and `git diff --check`. Request independent review through the implement skill; fix evidenced findings and refresh affected checks. Reconcile all acceptance criteria and record limitations. Obtain or execute the authorized branch outcome; never merge main or rewrite other stack branches.

## Execution record

- Baseline clean at `103d5fa5`; reused the approved existing checkout/branch instead of creating a new worktree. Design-approved synthetic gesture and isolated rendering boundaries apply.


## Completed implementation and review

- Observed the intended RED: `NotchMusicTrackSwipe` missing from the first 53.99/54-point behavioral test. Implemented and observed GREEN before native integration.
- Physical recognizer owns two-contact travel, direct raw horizontal direction, cancellation, progress and one action per stroke. The general recognizer retains vertical behavior and horizontal intent locking, with its old scroll-distance music action removed. Horizontal tests now exercise the physical seam instead of the deleted 40-scroll-point contract; repetitive legacy skip checks were removed.
- Native coordinator joins either event order. Early eligible phased direction expires after 0.15 seconds; cross-stream timestamps may be reordered within that bound. Missing physical data, momentum, replaced contacts, invalid data and rejected playback do not create a successful skip. Actual presentation/surface transitions cancel held input; fresh all-began contacts recover. Eligible native touch events are consumed and forwarded events deduplicated.
- Both notched and capsule compact players crossfade their visualizer/hover control into the directional symbol, retaining the existing accepted-command nudge. Extracted the capsule music strip and transport into small cohesive modules; expanded transport uses the neutral backdrop without whole-player displacement. Overlays preserve content bounds and hit targets. Reduce Motion retains opacity changes without scale or displacement.
- Independent review identified two P2 findings: actual scroll-before-touch-begin ordering and leave/return interruption without input. Both were fixed with synthetic regressions and re-reviewed as ready with no remaining actionable findings. The final small timestamp-order correction was also reported for review.
- A pre-existing CI/documentation fix advanced HEAD from `103d5fa5` to `55a4f3ad` during this task. It was preserved; gesture work remains separate and local.

## Verification

- Full `./build.sh --test`: `TESTS OK (112544 checks)`, plus preference cleanup, uninstall-spaces and developer-install isolation checks. This includes unchanged vertical/capture contracts and the new physical/controller regressions.
- After the final bounded cross-stream timestamp correction, `./build.sh --test-suite=notch`: `TESTS OK (66277 checks)`.
- Final `./build.sh --dev`: compiled, assembled and signed the Developer bundle successfully.
- Strict deep signature verification passed. Isolated copied-bundle selftest: `SELFTEST OK`.
- Isolated production-overlay rendering: `MUSIC_SWIPE_RENDERING_OK`, four dark/light and full/reduced-motion images at `/tmp/lattice-physical-swipe-render`. Visually inspected dark/full and light/reduced variants for both directions and 0/50/100% progress.
- `git diff --check` passed. New handwritten modules are below 300 lines.
- No real media command, scrolling preference, hardware setting or permission grant was changed. Real trackpad delivery/playback remains a manual runtime check; synthetic/native-boundary tests and source review do not claim that live verification.
- User selected topic commits and pushing `refactor/settings-refactor-III-part-2` only, with no PR edits or merge. Publication is verified separately after committing. Main and other branches remain outside this task.
