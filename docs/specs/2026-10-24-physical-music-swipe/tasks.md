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

## Follow-up: lift to commit and rapid skipping

User explicitly requested the behavior update after the initial implementation. Continue on part 2 / PR #11, baseline `049ce204` (preserving an unrelated completed Bluetooth fix). The system-icon permission fix is separately committed/pushed to part 5 / PR #14 at `305b84b3`.

- [x] RED: crossing 54 points previously sent immediately; new assertion required no action while held.
- [x] Arm on the same physical threshold; latch direction/progress while original fingers remain down. Commit once at the last lift, discard short or invalid/cancelled strokes. Process final ended positions before remaining contacts.
- [x] Keep active feedback alive until lift/cancellation rather than expiring after 0.5 seconds. Test a 0.6-second hold and staggered release using injected command callbacks only.
- [x] RED: compact track-notice availability policy was absent. Add the shared policy, use it in touch/scroll eligibility and stable compact surface identity, and cover three immediate separate strokes while the title/artist notice covers the strip.
- [x] Share the compact artwork cue between track notices in both island silhouettes, preserving appearance and settings-preview isolation. Keep existing playback authorization/command-busy checks.
- [x] Final affected regressions, developer build/signature, isolated rendering/selftest and independent review. Commit/publish this follow-up on part 2 only.

Initial isolated follow-up result: `MUSIC_LIFT_TESTS checks=42 failures=0`. No real media command, permission or hardware action was exercised.


Follow-up final verification:
- Independent review caught that AppKit's default resting-touch policy synthesizes an end when a finger rests. Enabled resting delivery on both native receiver sites; native snapshots retain resting contacts and the recognizer retains armed original identities through resting/partial lift. Inactive resting fingers cannot establish or advance the distance threshold. Added the resting snapshot to the sustained-hold regression. Re-review found no remaining actionable issues.
- Final notch regressions: `TESTS OK (66291 checks)` including vertical/capture, natural-scrolling direction, short/armed/cancelled/reordered strokes, sustained/resting/partial-lift feedback, notice availability and repeated notice-time gestures.
- Final Developer build and strict signature verification passed. Isolated native receiver probe: `MUSIC_SWIPE_RESTING_RECEIVERS_OK`; production overlay rendering: `MUSIC_SWIPE_RENDERING_OK`; isolated copied-bundle selftest: `SELFTEST OK`.
- `git diff --check` passed. No real player commands or permission/hardware changes were used for verification. The installed app is unchanged; these are branch/build outputs. No stack restack or PR metadata edit is included.


## Recovery, unified music display and staged haptics

Baseline `cf31fb32`, part 2. Approved plan: first-original-finger lift, half-inch travel, three-second inactivity cancellation, shared compact/full layout. Subsequent user steering replaces the timed haptic pair with start/armed taps and removes all soundtrack-change position nudges.

- [x] RED: updated half-inch/first-lift behavior failed against the old recognizer. Added synthetic missing-release/recovery, one-action latch, stage-feedback and invalid/stale input coverage; hardware remains injected.
- [x] Split the feedback state from the controller; add one cancel-only inactivity timer. Timeout never sends a track command. Distinguish same event identity at different timestamps. Resting contacts do not prevent a new active sequence after completion.
- [x] Trigger one haptic at sideways activation, another at arming, respecting the existing haptic preference. Remove delayed haptic scheduling and obsolete position-nudge publisher/modifiers.
- [x] RED: shared full-music layout helper absent. Route track notices through existing music strip renderers, force metadata visibility, place title/artist before artwork, retain right waveform/cue, measure artist width for capsule sizing, and retire alternate notice cue ownership.
- [x] Verify affected/full regressions and actual isolated full-music rendering, build/signature and selftest. Inspect full diff and tests after corrections.
- [x] Whole-diff self-review completed. Independent reviewer could not run due to a usage limit; report that limitation explicitly. Commit/push only part 2; preserve other stack slices.


Final recovery verification and self-review:
- Full regression run passed `TESTS OK (112603 checks)`, plus preference-cleanup, uninstall-space and developer-install-isolation checks. After the final native partial-packet release guard, focused notch regressions passed `TESTS OK (66305 checks)`.
- Whole-diff self-review checked physical-distance/arming/release, timer cancellation, duplicate suppression, haptic phase ownership and preference gating, native event normalization, notice geometry/metadata/artwork, snapshot/hold preservation, generated fixtures and retired nudge/cue references. Fixed missing-packet ambiguity by requiring an observed ended touch before native data can commit. Added RED/GREEN coverage; unconfirmed missing contacts cancel instead of guessing a release. Live notice artwork bypasses the compact strip's held-cover snapshot, and simulated-cutout rendering avoids duplicate metadata.
- Three capsule hold/identity regression expectations needed the new shared two-line sizing helper. Kept the original behavior assertions and moved their expected sizing to the approved renderer contract; all passed.
- Final developer build and strict signature verification passed. Native probes reported `MUSIC_SWIPE_RESTING_RECEIVERS_OK`, `MUSIC_SWIPE_RENDERING_OK`; isolated selftest reported `SELFTEST OK`.
- Actual full-view captures at 0/50/100% for physical notch, capsule and simulated cutout are in `/tmp/lattice-music-consistency-render`. Inspected title/artist/artwork and right-side cue/waveform placement. Full captures use an invisible, noninteractive native hosting window because ImageRenderer cannot draw the native waveform; pure overlay fixtures retain ImageRenderer. No live playback service was started.
- No real media command, haptic output, permission reset or hardware change was used for verification. The installed app was not replaced. Independent review remains unavailable; this batch received a documented self-review.
- Final source lookup found no `gestureSkips` or `NotchMusicSwipeFeedback` modifier references. The two haptic taps are tied to activation and arming, with no delayed haptic work or directional position offset.

### Quarter-inch feedback / four-thirds-inch arming

Baseline 685b5c92, part 2. Updated the recognizer and first-haptic gate to 18/96 physical points. Updated only directly affected gesture fixtures, including natural-scrolling, release/recovery, surface continuity and completion lifetime. RED reproduced 5 failures; the standalone focused gesture runner passed all 78 checks after correction. Skipped unrelated suites, full app build and rendering as requested for this localized distance adjustment. No real playback or haptic calls.

User corrected the requested arming distance from 4/3 inch to ¾ inch. Baseline 8c5d5fac: changed only the threshold to 54 physical points and the directly affected gesture fixtures (53.99/54 boundary, 27-point halfway progress). First haptic remains at 18 points. Only the same isolated gesture runner is required; unrelated suites and app builds remain skipped.
Focused verification passed all 78 checks. Independent source review found no actionable issues. No real media or hardware actions were performed.
