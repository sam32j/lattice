# Settings Follow-up Implementation Plan

**Goal:** Complete the approved settings follow-up, preserve existing work, and publish at least 30 topic commits without merging main.

**Architecture:** Page-owned toggles determine Bluetooth and display feature availability. Reuse native slider and app-list sheet controls, with per-shortcut mouse exclusions separate from Space gestures. Preserve permission and system-capability boundaries.

**Tech Stack:** Swift, SwiftUI, AppKit, existing generated Swift test fixtures, Icon Composer and native macOS packaging tools.

## Approved design
- Apply all 26 requested refinements, correcting obvious English typos.
- Duplicate-key protection: toggle, indented repeat-delay control and compact per-key override Add/Remove list. Disabled options remain visible.
- Bluetooth installation follows either setting, but wake restoration still only repays Bluetooth changes made by Lattice. Display installation follows Control displays. Both pages remain reachable without installation.
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
Design approved by user. Implementation pending. Existing changes are preserved; starting HEAD is 3f98d758.
