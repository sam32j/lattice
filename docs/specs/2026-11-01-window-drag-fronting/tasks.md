# Window Drag Fronting Implementation Plan

**Goal:** Bring the selected window forward once, then drag through the same responsive frame pipeline used with the option off.

**Architecture:** Serialize initial fronting, accessibility-mode preparation and coalesced frame writes on the existing gesture queue. Keep slow application operations outside the event callback. Preserve plain modifier-click custody, release ordering, cancellation, resizing and edge snapping.

**Tech Stack:** Swift, AppKit, Accessibility, native CGEvent callback fixtures and real dispatch queues.
---

Baseline: `b1268a2e` on `ui/settings-refinements`, main workspace. Other-agent edits are saved under `/private/tmp/lattice-window-fronting-baseline`, including its existing fronting changes in WindowLayoutService and SpaceWindowBridge. Preserve them outside the directly requested repair. No new commit or publication is authorized.

Approved seam: modifier-drag event entry point and macOS window-operation boundary, both toggle states, ordinary modifier-clicks, cancellation and slow Electron-style responses.

1. Add a native-event regression with a delayed window-server fronting response. Assert input remains responsive and no movement precedes fronting/preparation. Observe failure on current production callbacks.
2. Queue initial fronting before accessibility suspension and the first coalesced frame write. Remove concurrent background raise and release-time reactivation. Both toggle states keep one frame pipeline.
3. Extend behavior coverage to ordinary modifier-click pass-through, toggle-off frames, exact window identity, cancellation, resize, final-frame delivery and accessibility restoration. Use system-boundary substitutes only; execute real production callback/queue bodies.
4. Run focused window-layout/gesture checks and development compilation, obtain independent review, then verify actual native/Electron windows where available. Record limits and preserve all unrelated work.

Root-cause investigation: the current promotion suspends enhanced accessibility, asks WindowServer to front, launches AXRaise on a separate global queue, and immediately enqueues the first frame. AXRaise can overlap and finish after movement has begun. The option also adds app activation after release. A slow initial fronting call currently executes inside the event callback.

## Verification

- Observed the intended red failure: a simulated 150 ms WindowServer response stalled promotion for about 155 ms, and fronting occurred after accessibility suspension (`/private/tmp/lattice-window-fronting-red.log`).
- Initial green promotion returned in approximately 0.12 ms, with fronting and AXRaise completing before suspension and the first coalesced frame. No per-pointer front/focus operations were added.
- Final event/queue fixture passes 11 checks, plus 473 existing window-layout checks. It runs actual production CGEvent callback, promotion, frame application, coalescing and flush bodies on a real serial queue. Only OS window operations, preferences and the selected target are substituted. Covered slow startup, toggle-off behavior, modifier-click replay, selected-window identity, direct frame writes, fallback activation, resize, normal cancellation, cancellation during delayed startup and consecutive gestures. Log: `/private/tmp/lattice-window-fronting-final-tests.log`.
- Independent source review found no blocking production issue. Review identified two safety issues in the temporary real-window probe (generic release cleanup could replay an orphan OS click, and PID-only validation could select another same-app window); both were corrected and re-reviewed ready. Probe cleanup explicitly drops custody and drains/restores, replay is suppressed, and exact AX/CG window identity is checked before input.
- Actual native-window callback checks passed both modes, delivered the exact final frame and restored window position. Option off median/max drag callback: 0.0364/0.4046 ms; option on: 0.0299/0.1467 ms. These runs started foreground and therefore do not alone establish a background-to-front transition. Log: `/private/tmp/lattice-window-fronting-native.log`.
- The existing release/cancel flush remains synchronous to guarantee final-frame and accessibility restoration ordering. The repair removes startup and repeated-movement stalls; a release during a slow pending operation may still wait for it, as in the common pipeline.
- The full Electron UI-tree automation stalled; no further tree walks are used. WindowServer metadata shows the inactive fixture windows hidden, explaining why initial app-level AXWindows queries could find no target. The narrow temporary probe can explicitly activate a verified fixture WindowServer ID before querying it. Electron verification remains in progress.

## Final result

- The explicit Electron fixture (VS Code with a disposable profile, PID 31281/window 138152) passes both option states through the production event callback and frame queue. Final frame matches the expected pointer delta. Off median/max drag callbacks: 0.01075/0.11946 ms; on: 0.01362/0.03212 ms (`/private/tmp/lattice-window-fronting-electron.log`). Both runs began foreground; a physical background-to-front drag is not claimed as verified.
- Independent final review is **ready**, with no blocking findings. All temporary development probe source, CLI hooks, replay guards and entry points have been removed from the repository. Their copies and logs remain only under `/private/tmp/lattice-window-fronting-live/` for evidence. Disposable native and Electron app processes were closed; their window positions and modified drag preferences were restored by the probe.
- The final clean developer build compiled, installed and signed successfully (`/private/tmp/lattice-window-fronting-install.log`), and was relaunched from `/Applications/Lattice (Developer).app`. Final focused suites pass **484 checks** on the source without probe hooks (`/private/tmp/lattice-window-fronting-final-tests.log`). `git diff --check` passes.
- Byte comparisons against the saved dirty baseline confirm other-agent files are unchanged outside the requested WindowLayoutService repair and additive test-generator wiring. The other agent's separate preference/runtime and test-generator edits remain intact. All work for this follow-up remains uncommitted in the main workspace, with no push or merge.
