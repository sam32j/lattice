# Permission Cards Implementation Plan

**Goal:** Compact update actions and simplify Data and Permissions without changing permission or destructive-action behavior.

**Architecture:** Reuse the current settings-overhaul worktree. Keep permission services untouched; extract a presentation-only details sheet. Group each settings action and explanatory text in one Form row.

**Tech Stack:** SwiftUI, AppKit, standalone Swift regression harness.
---

1. Add a hosted regression for update layout at 490pt and verify the current
   stacked layout puts actions below status. Replace intrinsic-width fallback
   with a compressible horizontal row; run the regression again.
2. Add a hosted permission-sheet dismissal test. Implement the production
   details sheet, connect accessible per-row info buttons, and move usage and
   unused warnings off the main row. Verify Done/Escape and reopening.
3. Group reset/data/uninstall rows; preserve alerts and callbacks. Rename the
   uninstall heading in every locale, and remove the now-unused reset heading.
4. Run affected tests, developer build and selftest sequentially. Inspect actual
   Settings, including narrow update layout, permission details and grouped rows.
5. Obtain independent review and fix findings. Leave changes uncommitted in the
   existing feature worktree.

Status: implementation in progress.
