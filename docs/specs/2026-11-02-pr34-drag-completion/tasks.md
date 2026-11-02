# Asynchronous Drag Completion Implementation Plan

**Goal:** Return mouse-up and cancellation promptly while retaining final frames, accessibility restoration, exact window identity, snapping, and next-gesture ordering.

**Architecture:** Give each gesture a small coalescing session on the existing shared serial apply queue. Sealing a session captures its final pending frame and queues restoration after it. New preparation follows the old completion, reads the accepted window frame, and rebases its geometry. Session-tagged snap events cannot end a newer drag. Cancellation prevents queued work from starting while still restoring any suspension already acquired.

**Tech Stack:** Swift, Foundation dispatch queues and locks, AppKit/Accessibility, existing native-event fixtures with inert system boundaries.
---

The user approved asynchronous completion with preserved ordering. Continue in the established PR 34 checkout; preserve the unrelated deleted release video. The alternative was to retain synchronous completion and dispute the comment. A concurrent raise queue was rejected because it would race frames and restoration.

### Task 1: Reproduce release latency

Modify `Tests/WindowGestureFrontingRuntimeTests.swift` to measure mouse-up behind delayed fronting. Run `./build.sh --test-suite=window-layout`; record failure before changing production completion.

### Task 2: Isolate coalescing sessions

Create `Sources/Lattice/Services/WindowLayout/WindowGestureApplySession.swift`. Implement locked per-session pending state, sealing/final capture, cancellation, and shared-queue completion. Adapt `WindowLayoutService.swift` and generated runtime fixtures. Retain an explicit test drain; event callbacks never synchronously drain.

### Task 3: Preserve geometry and snapping

Read each exact target's accepted frame in queued preparation after the preceding session completes. Rebase move/resize geometry there. Tag forwarded begin/drag/up/drop events and reject stale completion. Preserve ordinary modifier-click replay. Extend the existing runtime tests for early release/cancel, consecutive gestures, resize, and delayed snap delivery.

### Task 4: Verify and review

Run window-layout and affected audio/input regressions, developer compilation/selftest, and independent review. Publish only after resolving findings. Retain the documented baseline-only native capture-focus failures separately; never claim physical hardware verification.
