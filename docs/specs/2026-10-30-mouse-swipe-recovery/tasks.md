# Magic Mouse Swipe Recovery Implementation Plan

**Goal:** Restore Magic Mouse track changes without changing trackpad travel, touch ownership, or first-swipe haptics.

**Architecture:** Retain native mouse acceptance and the existing scroll-threshold fallback. Recognize mouse streams that enter mid-scroll and recover from a native tracker that never responds. Explicit native cancellation remains authoritative. Trackpad contact recognition and haptic production files stay unchanged.

**Tech Stack:** Swift, AppKit, existing input/controller fixtures with inert callbacks.
---

1. Reproduce silent-native and late-entry failures at the existing controller input boundary, without hardware or native playback commands.
2. Add bounded mouse-only recovery, retaining precise-input, momentum, cancellation and physical-touch guards. Test single commit, late callback rejection, and recovery across input modes.
3. Pin cold-start compact trackpad feedback at existing physical-contact and haptic callback boundaries. Run original mouse, trackpad and surface regressions, compile, and request independent review.

Reference: Apple documents that Magic Mouse can move between views during a scroll, so a new view may first receive Changed rather than Began: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html

Baseline: a744719e, clean feature/dynamic-island-core. No hardware, settings, installation or running-app changes are authorized by this plan.

## Result

- Reproduced and fixed silent native tracking, Changed-first mouse entry, cancellation veto, queued duplicate native acceptance, and consecutive native/recovery state leakage.
- Changed-first recovery is passive: it does not invoke AppKit native capture. Native tracking remains authoritative when it responds, including acceptance below the existing 80-scroll-point recovery threshold.
- Added cancellation, reversal, timeout, late callback, playback failure, mouse-to-trackpad transition and first compact/hover-preview trackpad haptic coverage.
- Existing physical trackpad thresholds remain 18 points for activation feedback and 54 for arming. Trackpad recognizer/controller, haptic production code, touch receivers, and surface eligibility have no source changes.
- Final focused verification: 48,642 checks passed (notch-input 66, notch 47,514, settings 1,062). Developer executable compilation passed without signing or installation.
- Independent review found and verified correction of a duplicate-native-acceptance edge case; no remaining code blockers. Real Magic Mouse event delivery and physical launch-time haptics remain unverified on hardware.
- The first final-verification attempt was not executed because automatic approval review hit an account usage limit. The user requested continuation; the same approved checks were retried successfully.
