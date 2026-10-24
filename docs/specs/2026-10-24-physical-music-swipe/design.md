# Physical music swipe and progressive feedback

Approved October 24, 2026. Continue on the existing PR 11 branch, `refactor/settings-refactor-III-part-2`, baseline `103d5fa5`, in `/Users/samuel/Developer/Lattice`. Preserve the current vertical gesture and capture behavior.

- Measure two non-resting indirect touches using `NSTouch.normalizedPosition * deviceSize`. Apple's NSTouch header defines deviceSize as 72-ppi physical points; ¾ inch is 54 points. Both fingers must meet the horizontal travel requirement. Scroll deltas do not supply physical distance.
- Music skip direction uses macOS's preference-adjusted horizontal scroll delta directly: negative selects next, positive previous. Remove the normalize-then-invert horizontal path. Keep physical-direction normalization for vertical opening/closing gestures.
- Separate horizontal music input from the vertical scroll recognizer. One accepted command at most per contact sequence. No momentum-only, one-finger, replaced-finger, mixed-device or unmeasured-device skip. Invalid, cancelled, disallowed, interrupted or presentation-changing sequences reset their visible feedback and cannot resume midway.
- Native touches and scroll events may arrive in either order. Physical distance and scroll direction must both belong to an active eligible sequence before skipping. Under-threshold motion never changes a track.
- Compact: retain the existing accepted-command position nudge. Crossfade the visualizer/hover control into a next/previous glyph, scaling up with swipe progress without changing layout or hit targets.
- Expanded: remove the whole-player position nudge. Grow a neutral contrasting circle behind the corresponding previous/next transport glyph as travel progresses. Unsupported commands do not show successful completion feedback.
- Cancelled/incomplete swipes settle back; accepted swipes briefly acknowledge completion then clear. Respect Reduce Motion by fading without displacement or scale. No repeating timers survive a gesture.
- Keep capture touch behavior intact. Share native event delivery without letting capture and music recognize the same surface. Keep the existing playback permission/command boundary.
- Verification: synthetic contact/event traces, existing vertical/capture and playback regressions, isolated compact/expanded progress rendering including Reduce Motion, developer build/selftest and independent source review. Never send a real media command, change scrolling preferences or permissions during tests.

Design and implementation records remain local until the final branch outcome is selected or authorized.
