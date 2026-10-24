# Settings Follow-up Implementation Plan

**Goal:** Complete the approved settings follow-up, preserve existing work, and publish at least 30 topic commits without merging main.

**Architecture:** Page-owned toggles determine Bluetooth and display feature availability. Reuse native slider and app-list sheet controls, with per-shortcut mouse exclusions separate from Space gestures. Preserve permission and system-capability boundaries.

**Tech Stack:** Swift, SwiftUI, AppKit, existing generated Swift test fixtures, Icon Composer and native macOS packaging tools.

## Approved design
- Apply all 26 requested refinements, correcting obvious English typos.
- Duplicate-key protection: toggle, indented repeat-delay control and compact per-key override Add/Remove list. Disabled options remain visible.
- Bluetooth availability follows Turn Bluetooth off on sleep. Restore on wake is a saved subordinate option, disabled while sleep handling is off; pending restoration still repays Bluetooth changes made by Lattice independently. This supersedes the original either-toggle rule following the owner's October 24 review. Display installation follows Control displays. Both pages remain reachable without installation.
- Extra-button exclusions live in each configured shortcut editor. Space-drag gestures have no exclusions. Preserve existing exclusions through migration rather than silently dropping them.
- Investigate event-tap recovery and tooltip hit testing before selecting fixes.
- Import the latest Desktop/Lattice.icon once, update active app and README branding references, verify, commit by topic and push the existing branch. No merge to main or force-push is authorized by default.

## Execution tasks
1. Core/FeatureCatalog.swift, FeatureRuntime.swift, DisplaySettings.swift and navigation helpers: test page-owned installation combinations, implement gates, verify features/preferences suites.
2. EnergyDisplaySettings.swift and audio level rows: use trailing native sliders with tracking tooltips, preserve bindings and disabled states; render affected pages.
3. MouseScrollingSettings.swift, MousePointerSettings.swift, MouseSettings.swift and exception strings: implement visibility, indentation, concise ALS copy and trackpad choices; run pointer-input/localization suites.
4. MouseButtonSettings*.swift and Services/MouseButtons: reproduce capture failure paths, test recovery, implement per-shortcut exception storage/migration and exclusion-free Spaces behavior; run pointer-input/preferences suites.
5. Keyboard*Settings.swift and SettingsStatusDot.swift: regroup children, native delay controls, tooltip hit regions; run keyboard/settings suites and render states.
6. Resources/Brand and docs/assets/readme: import current user-supplied icon, compile adaptive/static assets, update referenced branding, verify source preservation and build.
7. Run focused suites, developer build, signature checks, selftest, rendering and whitespace checks. Review complete diff; record limitations.
8. Snapshot final work, create at least 30 nonempty topic commits, verify resulting tree and clean worktree, push origin/refactor/settings-refactor-III normally and verify remote HEAD.

## Status
Design approved by user. Implementation complete; starting HEAD was 3f98d758. Existing changes preserved.

## Verification and review
- Final seven suites: TESTS OK (31084 checks), covering pointer-input, features, settings, keyboard, preferences, localization and uninstaller.
- Developer build, strict bundle signature verification, bundled fallback comparison and SELFTEST OK passed. Latest Desktop icon source PNGs match byte-for-byte; JSON matches semantically. README and About now use the latest app artwork.
- Final isolated layout rendering passed all 24 fixtures at /tmp/lattice-follow-up-final.qgrNSY/rendered. Inspected scrolling, Super Key, duplicate-key protection and disabled display controls.
- Independent source review found event-source exclusion matching and a missing trackpad picker tag for a conflicting saved three-finger selection. Both fixed; source-matching regression failed before the fix and passed after. Re-review found no remaining blockers in those changes.
- Native tooltip presence and repeated production capture resynchronization are covered by generated test fixtures. Actual permission revocation/regrant, physical mouse capture and live tooltip hover are not exercised; no claim of hardware end-to-end verification.
- Normal capture retry now resynchronizes the listener even if capture is already requested; UI exposes Retry when the listener cannot watch. No restart or blind forced teardown of consumed mouse presses is required for retry.
- Per-shortcut exclusions preserve legacy list defaults until explicitly edited, including explicit empty overrides. Space drags bypass app exclusions.
- No installed app, Bluetooth power state, actual display brightness, real key mapping, Gatekeeper settings or Dock process was changed during verification.
- User approved including the four upstream branding deletions and cleaning references. Removed the now-unused upstream icon generator, its build fallback and the obsolete About badge; retained the separate menu-bar glyph. Updated generator references in comments. Deleted tracked assets remain recoverable from Git history.
- Publication authorized: topic commits and a normal push to origin/refactor/settings-refactor-III, with all app-icon source/static/README/About changes consolidated in one branding commit. No force-push, PR mutation or merge to main.
